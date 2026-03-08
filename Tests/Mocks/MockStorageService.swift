import Foundation
import UIKit
@testable import OneHome

// MARK: - StorageServiceProtocol
//
// Protocol mirroring StorageService's public interface.
// Ready for injection into PostViewModel tests once the ViewModel
// is refactored to accept an injected storage dependency.

protocol StorageServiceProtocol {
    /// Upload a UIImage as JPEG. Returns the public URL string.
    /// Path: {homeID}/{userID}/{postID}.jpg
    func uploadPostImage(_ image: UIImage, homeID: UUID, userID: UUID, postID: UUID) async throws -> String
    /// Delete the stored image for a post.
    func deletePostImage(homeID: UUID, userID: UUID, postID: UUID) async throws
}

// MARK: - MockStorageService
//
// A fully controllable stand-in for StorageService.
// Tests configure urlToReturn / errorToThrow before calling the method,
// then inspect call counts and captured parameters to verify correct behavior.

final class MockStorageService: StorageServiceProtocol {

    // MARK: Call Tracking

    /// Number of times uploadPostImage was called
    var uploadCallCount = 0
    /// Number of times deletePostImage was called
    var deleteCallCount = 0

    /// homeID from the most recent uploadPostImage call
    var lastUploadedHomeID: UUID?
    /// userID from the most recent uploadPostImage call
    var lastUploadedUserID: UUID?
    /// postID from the most recent uploadPostImage call
    var lastUploadedPostID: UUID?

    /// homeID from the most recent deletePostImage call
    var lastDeletedHomeID: UUID?
    /// userID from the most recent deletePostImage call
    var lastDeletedUserID: UUID?
    /// postID from the most recent deletePostImage call
    var lastDeletedPostID: UUID?

    // MARK: Configurable Return Values

    /// URL string returned by uploadPostImage on success
    var urlToReturn = "https://example.com/image.jpg"

    /// If set, all calls throw this error (simulates upload/delete failures)
    var errorToThrow: Error?

    // MARK: - StorageServiceProtocol

    func uploadPostImage(_ image: UIImage, homeID: UUID, userID: UUID, postID: UUID) async throws -> String {
        uploadCallCount += 1
        lastUploadedHomeID = homeID
        lastUploadedUserID = userID
        lastUploadedPostID = postID
        if let error = errorToThrow { throw error }
        return urlToReturn
    }

    func deletePostImage(homeID: UUID, userID: UUID, postID: UUID) async throws {
        deleteCallCount += 1
        lastDeletedHomeID = homeID
        lastDeletedUserID = userID
        lastDeletedPostID = postID
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    /// Reset all tracking state between tests
    func reset() {
        uploadCallCount = 0
        deleteCallCount = 0
        lastUploadedHomeID = nil
        lastUploadedUserID = nil
        lastUploadedPostID = nil
        lastDeletedHomeID = nil
        lastDeletedUserID = nil
        lastDeletedPostID = nil
        urlToReturn = "https://example.com/image.jpg"
        errorToThrow = nil
    }
}
