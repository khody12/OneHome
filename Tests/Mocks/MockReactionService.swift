import Foundation
@testable import OneHome

// MARK: - MockReactionService
//
// A fully controllable stand-in for ReactionService. Tests configure
// `reactionsToReturn`, `reactionToReturn`, `errorToThrow`, etc. before calling
// ViewModel methods, then inspect call counts and captured parameters.

final class MockReactionService: ReactionServiceProtocol {

    // MARK: Call Tracking

    /// Number of times addReaction was called
    var addReactionCallCount = 0
    /// Arguments from the most recent addReaction call
    var lastAddedPostID: UUID?
    var lastAddedUserID: UUID?
    var lastAddedEmoji: String?

    /// Number of times removeReaction was called
    var removeReactionCallCount = 0
    /// ID passed on the most recent removeReaction call
    var lastRemovedID: UUID?

    /// Number of times fetchReactions was called
    var fetchReactionsCallCount = 0
    /// postID passed on the most recent fetchReactions call
    var lastFetchedPostID: UUID?

    // MARK: Configurable Return Values

    /// The reactions returned from fetchReactions
    var reactionsToReturn: [Reaction] = []

    /// The reaction returned from addReaction
    var reactionToReturn: Reaction = Reaction(
        id: UUID(),
        postID: UUID(),
        userID: UUID(),
        emoji: "👍",
        createdAt: Date(),
        user: nil
    )

    /// If set, all calls throw this error (simulates service failures)
    var errorToThrow: Error?

    // MARK: - ReactionServiceProtocol

    func addReaction(postID: UUID, userID: UUID, emoji: String) async throws -> Reaction {
        addReactionCallCount += 1
        lastAddedPostID = postID
        lastAddedUserID = userID
        lastAddedEmoji = emoji
        if let error = errorToThrow { throw error }
        return reactionToReturn
    }

    func removeReaction(id: UUID) async throws {
        removeReactionCallCount += 1
        lastRemovedID = id
        if let error = errorToThrow { throw error }
    }

    func fetchReactions(for postID: UUID) async throws -> [Reaction] {
        fetchReactionsCallCount += 1
        lastFetchedPostID = postID
        if let error = errorToThrow { throw error }
        return reactionsToReturn
    }

    // MARK: Convenience Reset

    /// Reset all tracking state between tests
    func reset() {
        addReactionCallCount = 0
        lastAddedPostID = nil
        lastAddedUserID = nil
        lastAddedEmoji = nil
        removeReactionCallCount = 0
        lastRemovedID = nil
        fetchReactionsCallCount = 0
        lastFetchedPostID = nil
        reactionsToReturn = []
        reactionToReturn = Reaction(
            id: UUID(),
            postID: UUID(),
            userID: UUID(),
            emoji: "👍",
            createdAt: Date(),
            user: nil
        )
        errorToThrow = nil
    }
}
