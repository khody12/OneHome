import Foundation
@testable import OneHome

// MARK: - PaymentServiceProtocol
//
// Mirrors the public interface of PaymentService. ViewModels use the
// concrete singleton (.shared); tests inject a MockPaymentService via
// initializer to keep network calls out of the test suite.

protocol PaymentServiceProtocol {
    /// Create a payment request for a post and distribute splits to members
    func createRequest(
        postID: UUID,
        homeID: UUID,
        requestorID: UUID,
        totalAmount: Double,
        note: String,
        splits: [(userID: UUID, amount: Double)]
    ) async throws -> PaymentRequest

    /// Mark a single split as paid
    func markPaid(splitID: UUID) async throws

    /// Fetch the payment request associated with a given post, if any
    func fetchRequest(for postID: UUID) async throws -> PaymentRequest?
}

// MARK: - MockPaymentService
//
// A fully controllable stand-in for PaymentService. Tests configure
// `requestToReturn` / `errorToThrow` before calling ViewModel methods,
// then inspect call counts and captured arguments to verify behavior.

final class MockPaymentService: PaymentServiceProtocol {

    // MARK: Call Tracking

    /// Number of times createRequest was called
    var createCallCount = 0
    /// Arguments captured from the most recent createRequest call
    var lastCreatePostID: UUID?
    var lastCreateHomeID: UUID?
    var lastCreateRequestorID: UUID?
    var lastCreateTotalAmount: Double?
    var lastCreateNote: String?
    var lastCreateSplits: [(userID: UUID, amount: Double)]?

    /// Number of times markPaid was called
    var markPaidCallCount = 0
    /// splitID passed on the most recent markPaid call
    var lastMarkedPaidSplitID: UUID?

    /// Number of times fetchRequest was called
    var fetchCallCount = 0
    /// postID passed on the most recent fetchRequest call
    var lastFetchedPostID: UUID?

    // MARK: Configurable Return Values

    /// The PaymentRequest the mock returns (shared by create and fetch)
    var requestToReturn: PaymentRequest? = nil

    /// If set, all calls throw this error (simulates service failures)
    var errorToThrow: Error? = nil

    // MARK: - PaymentServiceProtocol

    func createRequest(
        postID: UUID,
        homeID: UUID,
        requestorID: UUID,
        totalAmount: Double,
        note: String,
        splits: [(userID: UUID, amount: Double)]
    ) async throws -> PaymentRequest {
        createCallCount += 1
        lastCreatePostID = postID
        lastCreateHomeID = homeID
        lastCreateRequestorID = requestorID
        lastCreateTotalAmount = totalAmount
        lastCreateNote = note
        lastCreateSplits = splits
        if let error = errorToThrow { throw error }
        guard let request = requestToReturn else {
            return Fake.paymentRequest(
                postID: postID,
                homeID: homeID,
                requestorID: requestorID,
                totalAmount: totalAmount,
                note: note
            )
        }
        return request
    }

    func markPaid(splitID: UUID) async throws {
        markPaidCallCount += 1
        lastMarkedPaidSplitID = splitID
        if let error = errorToThrow { throw error }
    }

    func fetchRequest(for postID: UUID) async throws -> PaymentRequest? {
        fetchCallCount += 1
        lastFetchedPostID = postID
        if let error = errorToThrow { throw error }
        return requestToReturn
    }

    // MARK: Convenience Reset

    /// Reset all tracking state and return values between tests
    func reset() {
        createCallCount = 0
        lastCreatePostID = nil
        lastCreateHomeID = nil
        lastCreateRequestorID = nil
        lastCreateTotalAmount = nil
        lastCreateNote = nil
        lastCreateSplits = nil

        markPaidCallCount = 0
        lastMarkedPaidSplitID = nil

        fetchCallCount = 0
        lastFetchedPostID = nil

        requestToReturn = nil
        errorToThrow = nil
    }
}
