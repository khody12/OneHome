import Foundation

@Observable
class PostDetailViewModel {
    var post: Post
    var comments: [Comment] = []
    var reactions: [Reaction] = []
    var commentText = ""
    var isLoadingComments = false
    var isSubmittingComment = false
    var errorMessage: String?
    var completionPost: Post?
    var reminderGrabs: [ReminderGrab] = []

    init(post: Post) {
        self.post = post
        self.comments = post.comments ?? []
        self.reactions = post.reactions ?? []
        self.reminderGrabs = post.reminder?.grabs ?? []
    }

    // MARK: - Reaction Summary

    /// Grouped reactions sorted by count desc, only emojis with count > 0.
    func reactionSummary(userID: UUID) -> [(emoji: String, count: Int, hasReacted: Bool)] {
        var grouped: [String: [Reaction]] = [:]
        for reaction in reactions {
            grouped[reaction.emoji, default: []].append(reaction)
        }
        return grouped
            .compactMap { emoji, group -> (emoji: String, count: Int, hasReacted: Bool)? in
                let count = group.count
                guard count > 0 else { return nil }
                let hasReacted = group.contains { $0.userID == userID }
                return (emoji: emoji, count: count, hasReacted: hasReacted)
            }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Load Details

    /// Fetches comments and, for request posts, the completion post if set.
    func loadDetails(userID: UUID) async {
#if DEBUG
        if post.homeID == DevPreview.home.id {
            return
        }
#endif
        isLoadingComments = true
        errorMessage = nil
        do {
            async let fetchedComments = PostService.shared.fetchComments(for: post.id)

            // Load completion post for request posts
            var fetchedCompletion: Post? = nil
            if post.category == .request, let completionID = post.completionPostID {
                fetchedCompletion = try await PostService.shared.fetchPost(id: completionID)
            }

            // Load grab history for reminder posts
            if post.isSystemPost, let reminderID = post.reminderID {
                reminderGrabs = try await HouseholdReminderService.shared.fetchGrabs(for: reminderID)
            }

            comments = try await fetchedComments
            completionPost = fetchedCompletion
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingComments = false
    }

    // MARK: - Mark Complete

    /// Marks this request as completed by the given reply post.
    func markComplete(with completionPostID: UUID) async {
#if DEBUG
        if post.homeID == DevPreview.home.id {
            post.completionPostID = completionPostID
            return
        }
#endif
        do {
            try await PostService.shared.completeRequest(requestPostID: post.id, completionPostID: completionPostID)
            post.completionPostID = completionPostID
            completionPost = try await PostService.shared.fetchPost(id: completionPostID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Reactions

    func loadReactions(postID: UUID) async {
#if DEBUG
        if post.homeID == DevPreview.home.id {
            // Only seed from DevPreview if the post didn't already carry reactions
            // from the feed (e.g. user reacted before opening the detail sheet).
            if reactions.isEmpty {
                reactions = DevPreview.reactions.filter { $0.postID == postID }
            }
            return
        }
#endif
        do {
            reactions = try await ReactionService.shared.fetchReactions(for: postID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle Reaction

    /// If the current user already has this emoji reaction, remove it (optimistic);
    /// otherwise add it (optimistic). DEBUG guard skips network for dev home.
    func toggleReaction(emoji: String, userID: UUID) async {
        if let existing = reactions.first(where: { $0.userID == userID && $0.emoji == emoji }) {
            // Optimistic remove
            reactions.removeAll { $0.id == existing.id }
#if DEBUG
            if post.homeID == DevPreview.home.id { return }
#endif
            do {
                try await ReactionService.shared.removeReaction(id: existing.id)
            } catch {
                // Revert on failure
                reactions.append(existing)
                errorMessage = error.localizedDescription
            }
        } else {
            // Optimistic add
            let optimistic = Reaction(
                id: UUID(),
                postID: post.id,
                userID: userID,
                emoji: emoji,
                createdAt: Date(),
                user: nil
            )
            reactions.append(optimistic)
#if DEBUG
            if post.homeID == DevPreview.home.id { return }
#endif
            do {
                let saved = try await ReactionService.shared.addReaction(postID: post.id, userID: userID, emoji: emoji)
                // Replace optimistic with real
                if let idx = reactions.firstIndex(where: { $0.id == optimistic.id }) {
                    reactions[idx] = saved
                }
            } catch {
                // Revert on failure
                reactions.removeAll { $0.id == optimistic.id }
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Submit Comment

    /// Submits a new comment. Adds it optimistically before the service call completes.
    /// Empty or whitespace-only text is a no-op.
    func submitComment(userID: UUID, currentUser: User) async {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            commentText = ""
            return
        }

        // Build an optimistic comment to show immediately
        let optimistic = Comment(
            id: UUID(),
            postID: post.id,
            userID: userID,
            text: trimmed,
            createdAt: Date(),
            author: currentUser
        )
        comments.append(optimistic)
        commentText = ""
        isSubmittingComment = true

        do {
#if DEBUG
            // In dev mode just keep the optimistic comment, skip network
            if post.homeID == DevPreview.home.id {
                post.comments = comments
                isSubmittingComment = false
                return
            }
#endif
            let saved = try await PostService.shared.addComment(postID: post.id, userID: userID, text: trimmed)
            // Replace the optimistic entry with the real one from the server
            if let idx = comments.firstIndex(where: { $0.id == optimistic.id }) {
                comments[idx] = saved
            }
            post.comments = comments
        } catch {
            // Remove the optimistic comment on failure
            comments.removeAll { $0.id == optimistic.id }
            errorMessage = error.localizedDescription
        }
        isSubmittingComment = false
    }
}
