import Foundation
@testable import OneHome

// MARK: - SubscriptionServiceProtocol
//
// Mirrors the public interface of SubscriptionService. Tests inject a
// MockSubscriptionService via initializer to avoid any Supabase calls.

protocol SubscriptionServiceProtocol {
    /// Fetch all subscriptions for a home, ordered by creation date descending
    func fetchSubscriptions(for homeID: UUID) async throws -> [Subscription]
    /// Create a subscription and attach the given member user IDs
    func createSubscription(_ sub: Subscription, memberIDs: [UUID]) async throws -> Subscription
    /// Delete a subscription and all its member rows
    func deleteSubscription(id: UUID) async throws
}

// MARK: - MockSubscriptionService
//
// A fully controllable stand-in for SubscriptionService. Configure
// `subscriptionsToReturn` / `errorToThrow` before exercising the VM,
// then inspect call counts and captured arguments to verify behavior.

final class MockSubscriptionService: SubscriptionServiceProtocol {

    // MARK: Call Tracking

    /// Number of times fetchSubscriptions was called
    var fetchCallCount = 0
    /// homeID passed on the most recent fetchSubscriptions call
    var lastFetchedHomeID: UUID?

    /// Number of times createSubscription was called
    var createCallCount = 0
    /// Subscription passed on the most recent createSubscription call
    var lastCreatedSubscription: Subscription?
    /// memberIDs passed on the most recent createSubscription call
    var lastCreatedMemberIDs: [UUID]?

    /// Number of times deleteSubscription was called
    var deleteCallCount = 0
    /// id passed on the most recent deleteSubscription call
    var lastDeletedID: UUID?

    // MARK: Configurable Return Values

    /// The list of subscriptions returned from fetchSubscriptions
    var subscriptionsToReturn: [Subscription] = []

    /// The subscription returned from createSubscription
    var subscriptionToReturn: Subscription? = nil

    /// If set, all calls throw this error (simulates service failures)
    var errorToThrow: Error? = nil

    // MARK: - SubscriptionServiceProtocol

    func fetchSubscriptions(for homeID: UUID) async throws -> [Subscription] {
        fetchCallCount += 1
        lastFetchedHomeID = homeID
        if let error = errorToThrow { throw error }
        return subscriptionsToReturn
    }

    func createSubscription(_ sub: Subscription, memberIDs: [UUID]) async throws -> Subscription {
        createCallCount += 1
        lastCreatedSubscription = sub
        lastCreatedMemberIDs = memberIDs
        if let error = errorToThrow { throw error }
        return subscriptionToReturn ?? sub
    }

    func deleteSubscription(id: UUID) async throws {
        deleteCallCount += 1
        lastDeletedID = id
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    /// Reset all tracking state and return values between tests
    func reset() {
        fetchCallCount = 0
        lastFetchedHomeID = nil

        createCallCount = 0
        lastCreatedSubscription = nil
        lastCreatedMemberIDs = nil

        deleteCallCount = 0
        lastDeletedID = nil

        subscriptionsToReturn = []
        subscriptionToReturn = nil
        errorToThrow = nil
    }
}
