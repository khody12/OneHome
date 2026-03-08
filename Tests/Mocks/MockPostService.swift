import Foundation
@testable import OneHome

// MARK: - MockPostService
//
// A fully controllable stand-in for PostService. Tests configure `feedToReturn`,
// `errorToThrow`, etc. before calling ViewModel methods, then inspect call
// counts and captured parameters to verify correct behavior.

final class MockPostService: PostServiceProtocol {

    // MARK: Call Tracking

    /// Number of times fetchFeed was called
    var fetchFeedCallCount = 0
    /// homeID passed on the most recent fetchFeed call
    var lastFetchedHomeID: UUID?

    /// Number of times toggleKudos was called
    var toggleKudosCallCount = 0
    /// postID passed on the most recent toggleKudos call
    var lastToggledPostID: UUID?
    /// userID passed on the most recent toggleKudos call
    var lastToggledUserID: UUID?
    /// hasKudos flag passed on the most recent toggleKudos call
    var lastToggledHasKudos: Bool?

    /// Number of times addComment was called
    var addCommentCallCount = 0
    /// Arguments from the most recent addComment call
    var lastCommentPostID: UUID?
    var lastCommentUserID: UUID?
    var lastCommentText: String?

    /// Number of times createDraft was called
    var createDraftCallCount = 0
    /// Arguments from the most recent createDraft call
    var lastDraftHomeID: UUID?
    var lastDraftUserID: UUID?
    var lastDraftCategory: PostCategory?

    /// Number of times publish was called
    var publishCallCount = 0
    /// postID passed on the most recent publish call
    var lastPublishedPostID: UUID?

    /// Number of times updateDraft was called
    var updateDraftCallCount = 0
    /// Post passed on the most recent updateDraft call
    var lastUpdatedDraft: Post?

    // MARK: Configurable Return Values

    /// The feed the mock returns from fetchFeed
    var feedToReturn: [Post] = []

    /// If set, all calls throw this error (simulates service failures)
    var errorToThrow: Error?

    /// The post returned from createDraft
    var draftToReturn: Post = Fake.draftPost()

    /// The comment returned from addComment
    var commentToReturn: Comment = Fake.comment()

    // MARK: - PostServiceProtocol

    func fetchFeed(for homeID: UUID) async throws -> [Post] {
        fetchFeedCallCount += 1
        lastFetchedHomeID = homeID
        if let error = errorToThrow { throw error }
        return feedToReturn
    }

    func toggleKudos(postID: UUID, userID: UUID, hasKudos: Bool) async throws {
        toggleKudosCallCount += 1
        lastToggledPostID = postID
        lastToggledUserID = userID
        lastToggledHasKudos = hasKudos
        if let error = errorToThrow { throw error }
    }

    func addComment(postID: UUID, userID: UUID, text: String) async throws -> Comment {
        addCommentCallCount += 1
        lastCommentPostID = postID
        lastCommentUserID = userID
        lastCommentText = text
        if let error = errorToThrow { throw error }
        return commentToReturn
    }

    func createDraft(homeID: UUID, userID: UUID, category: PostCategory) async throws -> Post {
        createDraftCallCount += 1
        lastDraftHomeID = homeID
        lastDraftUserID = userID
        lastDraftCategory = category
        if let error = errorToThrow { throw error }
        return draftToReturn
    }

    func publish(postID: UUID) async throws {
        publishCallCount += 1
        lastPublishedPostID = postID
        if let error = errorToThrow { throw error }
    }

    func updateDraft(_ post: Post) async throws {
        updateDraftCallCount += 1
        lastUpdatedDraft = post
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    /// Reset all tracking state between tests
    func reset() {
        fetchFeedCallCount = 0
        lastFetchedHomeID = nil
        toggleKudosCallCount = 0
        lastToggledPostID = nil
        lastToggledUserID = nil
        lastToggledHasKudos = nil
        addCommentCallCount = 0
        lastCommentPostID = nil
        lastCommentUserID = nil
        lastCommentText = nil
        createDraftCallCount = 0
        lastDraftHomeID = nil
        lastDraftUserID = nil
        lastDraftCategory = nil
        publishCallCount = 0
        lastPublishedPostID = nil
        updateDraftCallCount = 0
        lastUpdatedDraft = nil
        feedToReturn = []
        errorToThrow = nil
        draftToReturn = Fake.draftPost()
        commentToReturn = Fake.comment()
    }
}
