import SwiftUI

@Observable
class FeedViewModel {
    var feedItems: [FeedItem] = []
    var isLoading = false
    var errorMessage: String?
    var slackers: [UserMetrics] = []

    // Load and merge posts + sticky notes into a single chronological feed
    func loadFeed(for home: Home) async {
#if DEBUG
        // Use fake data in simulator so the feed is populated without a backend
        if home.id == DevPreview.home.id {
            var items = DevPreview.feedItems
            let systemPosts = systemPostsForDueReminders(DevPreview.reminders, home: home)
            items += systemPosts.map { .post($0) }
            items.sort { $0.createdAt > $1.createdAt }
            feedItems = items
            slackers = DevPreview.metrics.filter { $0.isSlacking(comparedTo: DevPreview.metrics) }
            return
        }
#endif
        isLoading = true
        errorMessage = nil
        do {
            async let posts = PostService.shared.fetchFeed(for: home.id)
            async let notes = StickyNoteService.shared.fetchActive(for: home.id)
            async let metrics = MetricsService.shared.fetchMetrics(for: home.id)
            async let reminders = HouseholdReminderService.shared.fetchReminders(for: home.id)

            let (fetchedPosts, fetchedNotes, fetchedMetrics, fetchedReminders) = try await (posts, notes, metrics, reminders)

            var items: [FeedItem] = fetchedPosts.map { .post($0) }
            items += fetchedNotes.map { .stickyNote($0) }

            let systemPosts = systemPostsForDueReminders(fetchedReminders, home: home)
            items += systemPosts.map { .post($0) }

            feedItems = items.sorted { $0.createdAt > $1.createdAt }

            slackers = fetchedMetrics.filter { $0.isSlacking(comparedTo: fetchedMetrics) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - System posts for due reminders

    private func systemPostsForDueReminders(_ reminders: [HouseholdReminder], home: Home) -> [Post] {
        let homeAuthor = User(
            id: home.id,
            username: "__home__",
            name: home.name,
            email: "",
            avatarURL: nil,
            createdAt: home.createdAt,
            venmoUsername: nil,
            paypalUsername: nil
        )

        return reminders.filter { $0.isActiveInFeed }.map { reminder in
            var post = Post(
                id: reminder.id,
                homeID: reminder.homeID,
                userID: home.id,
                category: .general,
                text: "🔔 \(reminder.emoji) \(reminder.name) is running low! Who's picking it up?",
                imageURL: nil,
                isDraft: false,
                createdAt: reminder.nextDueAt ?? reminder.createdAt,
                reactions: nil,
                comments: [],
                author: homeAuthor,
                paymentRequest: nil,
                requestedUserIDs: nil,
                completionPostID: nil,
                choreSubcategory: nil
            )
            post.isSystemPost = true
            post.reminderID = reminder.id
            post.reminder = reminder
            post.homeMembers = home.members ?? []
            return post
        }
    }

    // MARK: - Claim reminder

    func claimReminder(reminderID: UUID, claimer: User, home: Home) async {
        // Optimistically update the system post to show the claimer — post stays in feed
        for i in feedItems.indices {
            if case .post(var p) = feedItems[i], p.reminderID == reminderID {
                p.reminder?.currentClaimerID = claimer.id
                p.reminder?.currentClaimerUser = claimer
                // Also add a grab record optimistically
                let optimisticGrab = ReminderGrab(
                    id: UUID(), reminderID: reminderID,
                    userID: claimer.id, grabbedAt: Date(), user: claimer
                )
                let existingGrabs = p.reminder?.grabs ?? []
                p.reminder?.grabs = [optimisticGrab] + existingGrabs
                feedItems[i] = .post(p)
                break
            }
        }
#if DEBUG
        if home.id == DevPreview.home.id { return }
#endif
        do {
            try await HouseholdReminderService.shared.claimReminder(id: reminderID, byUserID: claimer.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addReaction(emoji: String, on post: Post, userID: UUID) async {
        // Optimistically update feedItems regardless of dev/prod
        func applyReactionToggle() {
            guard let idx = feedItems.firstIndex(where: {
                if case .post(let p) = $0 { return p.id == post.id }
                return false
            }) else { return }
            if case .post(var p) = feedItems[idx] {
                let alreadyReacted = p.reactions?.contains { $0.userID == userID && $0.emoji == emoji } ?? false
                if alreadyReacted {
                    p.reactions?.removeAll { $0.userID == userID && $0.emoji == emoji }
                } else {
                    let newReaction = Reaction(id: UUID(), postID: post.id, userID: userID, emoji: emoji, createdAt: Date(), user: nil)
                    if p.reactions == nil { p.reactions = [] }
                    p.reactions?.append(newReaction)
                }
                feedItems[idx] = .post(p)
            }
        }

        applyReactionToggle()

#if DEBUG
        if post.homeID == DevPreview.home.id { return }
#endif
        do {
            _ = try await ReactionService.shared.addReaction(postID: post.id, userID: userID, emoji: emoji)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addStickyNote(text: String, home: Home, userID: UUID) async {
#if DEBUG
        if home.id == DevPreview.home.id {
            let author = DevPreview.home.members?.first { $0.id == userID } ?? DevPreview.user
            let note = StickyNote(
                id: UUID(), homeID: home.id, userID: userID,
                text: text, createdAt: Date(),
                expiresAt: Date().addingTimeInterval(48 * 3600),
                author: author
            )
            feedItems.insert(.stickyNote(note), at: 0)
            return
        }
#endif
        do {
            let note = try await StickyNoteService.shared.post(text: text, homeID: home.id, userID: userID)
            feedItems.insert(.stickyNote(note), at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
