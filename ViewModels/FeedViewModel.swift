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
            feedItems = DevPreview.feedItems
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

            let (fetchedPosts, fetchedNotes, fetchedMetrics) = try await (posts, notes, metrics)

            var items: [FeedItem] = fetchedPosts.map { .post($0) }
            items += fetchedNotes.map { .stickyNote($0) }
            feedItems = items.sorted { $0.createdAt > $1.createdAt }

            slackers = fetchedMetrics.filter { $0.isSlacking(comparedTo: fetchedMetrics) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleKudos(on post: Post, userID: UUID) async {
        // Optimistic update
        if let idx = feedItems.firstIndex(where: {
            if case .post(let p) = $0 { return p.id == post.id }
            return false
        }) {
            if case .post(var p) = feedItems[idx] {
                p.hasGivenKudos.toggle()
                p.kudosCount += p.hasGivenKudos ? 1 : -1
                feedItems[idx] = .post(p)
            }
        }
        try? await PostService.shared.toggleKudos(postID: post.id, userID: userID, hasKudos: post.hasGivenKudos)
    }

    func addStickyNote(text: String, home: Home, userID: UUID) async {
        do {
            let note = try await StickyNoteService.shared.post(text: text, homeID: home.id, userID: userID)
            feedItems.insert(.stickyNote(note), at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
