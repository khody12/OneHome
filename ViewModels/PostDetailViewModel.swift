import Foundation

@Observable
class PostDetailViewModel {
    var post: Post
    var comments: [Comment] = []
    var kudosUsers: [User] = []
    var commentText = ""
    var isLoadingComments = false
    var isSubmittingComment = false
    var errorMessage: String?

    // Local animation state for kudos button
    var kudosBounce = false

    init(post: Post) {
        self.post = post
        self.comments = post.comments ?? []
    }

    // MARK: - Load Details

    /// Fetches the full comment list and the list of users who gave kudos.
    func loadDetails(userID: UUID) async {
#if DEBUG
        // In dev mode, comments are already seeded from the post — skip network call
        if post.homeID == DevPreview.home.id { return }
#endif
        isLoadingComments = true
        errorMessage = nil
        do {
            async let fetchedComments = PostService.shared.fetchComments(for: post.id)
            async let fetchedKudosUsers = PostService.shared.fetchKudosUsers(for: post.id)
            let (c, k) = try await (fetchedComments, fetchedKudosUsers)
            comments = c
            kudosUsers = k
            post.hasGivenKudos = k.contains { $0.id == userID }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingComments = false
    }

    // MARK: - Toggle Kudos

    /// Optimistically toggles kudos state and syncs with the backend.
    func toggleKudos(userID: UUID) async {
        // Animate
        kudosBounce = true
        // Optimistic update
        let wasGiven = post.hasGivenKudos
        post.hasGivenKudos.toggle()
        post.kudosCount += post.hasGivenKudos ? 1 : -1

        if post.hasGivenKudos {
            // Optimistically add a placeholder user entry if not already there
            if !kudosUsers.contains(where: { $0.id == userID }) {
                // We don't have the full User object here yet; reload after service call
            }
        } else {
            kudosUsers.removeAll { $0.id == userID }
        }

        do {
#if DEBUG
            if post.homeID == DevPreview.home.id { return }
#endif
            try await PostService.shared.toggleKudos(postID: post.id, userID: userID, hasKudos: wasGiven)
            kudosUsers = (try? await PostService.shared.fetchKudosUsers(for: post.id)) ?? kudosUsers
        } catch {
            // Revert on failure
            post.hasGivenKudos = wasGiven
            post.kudosCount += wasGiven ? 1 : -1
            errorMessage = error.localizedDescription
        }

        // Reset bounce trigger after a short delay so it can re-trigger next tap
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            kudosBounce = false
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
            if post.homeID == DevPreview.home.id { isSubmittingComment = false; return }
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
