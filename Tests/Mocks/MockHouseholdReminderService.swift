import Foundation
@testable import OneHome

// MARK: - MockHouseholdReminderService

class MockHouseholdReminderService: HouseholdReminderServiceProtocol {
    // MARK: Stored call arguments for assertion

    var fetchCallCount = 0
    var lastFetchedHomeID: UUID?

    var createCallCount = 0
    var lastCreatedName: String?
    var lastCreatedEmoji: String?
    var lastCreatedIntervalDays: Int?

    var clearCallCount = 0
    var lastClearedID: UUID?
    var lastClearedByUserID: UUID?

    var deleteCallCount = 0
    var lastDeletedID: UUID?

    // MARK: Configurable responses

    var remindersToReturn: [HouseholdReminder] = []
    var shouldThrowOnFetch = false
    var shouldThrowOnCreate = false
    var shouldThrowOnClear = false
    var shouldThrowOnDelete = false

    // MARK: Protocol conformance

    func fetchReminders(for homeID: UUID) async throws -> [HouseholdReminder] {
        fetchCallCount += 1
        lastFetchedHomeID = homeID
        if shouldThrowOnFetch { throw AppError.notFound }
        return remindersToReturn
    }

    func createReminder(homeID: UUID, userID: UUID, name: String, emoji: String, intervalDays: Int) async throws -> HouseholdReminder {
        createCallCount += 1
        lastCreatedName = name
        lastCreatedEmoji = emoji
        lastCreatedIntervalDays = intervalDays
        if shouldThrowOnCreate { throw AppError.notFound }
        return HouseholdReminder(
            id: UUID(),
            homeID: homeID,
            name: name,
            emoji: emoji,
            intervalDays: intervalDays,
            lastClearedAt: nil,
            lastClearedByUserID: nil,
            lastClearedByUser: nil,
            createdAt: Date(),
            createdByUserID: userID
        )
    }

    func clearReminder(id: UUID, byUserID: UUID) async throws {
        clearCallCount += 1
        lastClearedID = id
        lastClearedByUserID = byUserID
        if shouldThrowOnClear { throw AppError.notFound }
    }

    func deleteReminder(id: UUID) async throws {
        deleteCallCount += 1
        lastDeletedID = id
        if shouldThrowOnDelete { throw AppError.notFound }
    }
}
