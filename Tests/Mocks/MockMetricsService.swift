import Foundation
@testable import OneHome

// MARK: - MockMetricsService
//
// Controls MetricsService behavior in tests. Lets tests configure which
// metrics are returned (to drive slacker detection) and verify that
// recordPost is called with the right arguments after a publish.

final class MockMetricsService: MetricsServiceProtocol {

    // MARK: Call Tracking

    var fetchMetricsCallCount = 0
    var lastFetchedMetricsHomeID: UUID?

    var recordPostCallCount = 0
    var lastRecordedUserID: UUID?
    var lastRecordedHomeID: UUID?
    var lastRecordedCategory: PostCategory?
    var lastRecordedAmount: Double?

    // MARK: Configurable Return Values

    /// Metrics returned by fetchMetrics
    var metricsToReturn: [UserMetrics] = []

    /// If set, all calls throw this error
    var errorToThrow: Error?

    // MARK: - MetricsServiceProtocol

    func fetchMetrics(for homeID: UUID) async throws -> [UserMetrics] {
        fetchMetricsCallCount += 1
        lastFetchedMetricsHomeID = homeID
        if let error = errorToThrow { throw error }
        return metricsToReturn
    }

    func recordPost(userID: UUID, homeID: UUID, category: PostCategory, amount: Double) async throws {
        recordPostCallCount += 1
        lastRecordedUserID = userID
        lastRecordedHomeID = homeID
        lastRecordedCategory = category
        lastRecordedAmount = amount
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    func reset() {
        fetchMetricsCallCount = 0
        lastFetchedMetricsHomeID = nil
        recordPostCallCount = 0
        lastRecordedUserID = nil
        lastRecordedHomeID = nil
        lastRecordedCategory = nil
        lastRecordedAmount = nil
        metricsToReturn = []
        errorToThrow = nil
    }
}
