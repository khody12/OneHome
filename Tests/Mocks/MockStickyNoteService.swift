import Foundation
@testable import OneHome

// MARK: - MockStickyNoteService
//
// Controls StickyNoteService behavior in tests. Lets tests assert that
// sticky notes are posted with correct homeID/userID and that active
// notes are fetched before feed assembly.

final class MockStickyNoteService: StickyNoteServiceProtocol {

    // MARK: Call Tracking

    var postCallCount = 0
    var lastPostedText: String?
    var lastPostedHomeID: UUID?
    var lastPostedUserID: UUID?

    var fetchActiveCallCount = 0
    var lastFetchedActiveHomeID: UUID?

    var deleteCallCount = 0
    var lastDeletedNoteID: UUID?

    // MARK: Configurable Return Values

    /// The note returned by post()
    var noteToReturn: StickyNote = Fake.stickyNote()

    /// Notes returned by fetchActive()
    var notesToReturn: [StickyNote] = []

    /// If set, all calls throw this error
    var errorToThrow: Error?

    // MARK: - StickyNoteServiceProtocol

    func post(text: String, homeID: UUID, userID: UUID) async throws -> StickyNote {
        postCallCount += 1
        lastPostedText = text
        lastPostedHomeID = homeID
        lastPostedUserID = userID
        if let error = errorToThrow { throw error }
        return noteToReturn
    }

    func fetchActive(for homeID: UUID) async throws -> [StickyNote] {
        fetchActiveCallCount += 1
        lastFetchedActiveHomeID = homeID
        if let error = errorToThrow { throw error }
        return notesToReturn
    }

    func delete(noteID: UUID) async throws {
        deleteCallCount += 1
        lastDeletedNoteID = noteID
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    func reset() {
        postCallCount = 0
        lastPostedText = nil
        lastPostedHomeID = nil
        lastPostedUserID = nil
        fetchActiveCallCount = 0
        lastFetchedActiveHomeID = nil
        deleteCallCount = 0
        lastDeletedNoteID = nil
        noteToReturn = Fake.stickyNote()
        notesToReturn = []
        errorToThrow = nil
    }
}
