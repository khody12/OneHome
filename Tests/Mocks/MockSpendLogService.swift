import Foundation
@testable import OneHome

// MARK: - SpendLogServiceProtocol
//
// Mirrors the public interface of SpendLogService. Tests inject a
// MockSpendLogService via initializer to keep the test suite free of
// Supabase calls.

protocol SpendLogServiceProtocol {
    /// Fetch all spend logs for a home, ordered by creation date descending
    func fetchLogs(for homeID: UUID) async throws -> [SpendLog]
    /// Record a new spend entry for a user in a home
    func logSpend(
        homeID: UUID,
        userID: UUID,
        amount: Double,
        category: SpendCategory,
        note: String
    ) async throws -> SpendLog
    /// Delete a spend log entry by ID
    func deleteLog(id: UUID) async throws
}

// MARK: - MockSpendLogService
//
// A fully controllable stand-in for SpendLogService. Configure
// `logsToReturn` / `errorToThrow` before exercising the VM, then
// inspect call counts and captured arguments to verify behavior.

final class MockSpendLogService: SpendLogServiceProtocol {

    // MARK: Call Tracking

    /// Number of times fetchLogs was called
    var fetchCallCount = 0
    /// homeID passed on the most recent fetchLogs call
    var lastFetchedHomeID: UUID?

    /// Number of times logSpend was called
    var logSpendCallCount = 0
    /// Arguments captured from the most recent logSpend call
    var lastLogHomeID: UUID?
    var lastLogUserID: UUID?
    var lastLogAmount: Double?
    var lastLogCategory: SpendCategory?
    var lastLogNote: String?

    /// Number of times deleteLog was called
    var deleteCallCount = 0
    /// id passed on the most recent deleteLog call
    var lastDeletedID: UUID?

    // MARK: Configurable Return Values

    /// The list of logs returned from fetchLogs
    var logsToReturn: [SpendLog] = []

    /// The log returned from logSpend
    var logToReturn: SpendLog? = nil

    /// If set, all calls throw this error (simulates service failures)
    var errorToThrow: Error? = nil

    // MARK: - SpendLogServiceProtocol

    func fetchLogs(for homeID: UUID) async throws -> [SpendLog] {
        fetchCallCount += 1
        lastFetchedHomeID = homeID
        if let error = errorToThrow { throw error }
        return logsToReturn
    }

    func logSpend(
        homeID: UUID,
        userID: UUID,
        amount: Double,
        category: SpendCategory,
        note: String
    ) async throws -> SpendLog {
        logSpendCallCount += 1
        lastLogHomeID = homeID
        lastLogUserID = userID
        lastLogAmount = amount
        lastLogCategory = category
        lastLogNote = note
        if let error = errorToThrow { throw error }
        return logToReturn ?? Fake.spendLog(
            homeID: homeID,
            userID: userID,
            amount: amount,
            category: category,
            note: note
        )
    }

    func deleteLog(id: UUID) async throws {
        deleteCallCount += 1
        lastDeletedID = id
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    /// Reset all tracking state and return values between tests
    func reset() {
        fetchCallCount = 0
        lastFetchedHomeID = nil

        logSpendCallCount = 0
        lastLogHomeID = nil
        lastLogUserID = nil
        lastLogAmount = nil
        lastLogCategory = nil
        lastLogNote = nil

        deleteCallCount = 0
        lastDeletedID = nil

        logsToReturn = []
        logToReturn = nil
        errorToThrow = nil
    }
}
