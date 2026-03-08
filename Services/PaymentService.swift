import Foundation
import Supabase

class PaymentService {
    static let shared = PaymentService()
    private init() {}

    // MARK: - Create

    /// Create a payment request with splits for selected roommates.
    func createRequest(
        postID: UUID,
        homeID: UUID,
        requestorID: UUID,
        totalAmount: Double,
        note: String,
        splits: [(userID: UUID, amount: Double)]
    ) async throws -> PaymentRequest {
        let requestInsert = PaymentRequestInsert(
            postID: postID,
            homeID: homeID,
            requestorID: requestorID,
            totalAmount: totalAmount,
            note: note
        )
        let requests: [PaymentRequest] = try await supabase
            .from("payment_requests")
            .insert(requestInsert)
            .select("*, splits:payment_splits(*, user:users(*))")
            .execute()
            .value
        guard var request = requests.first else { throw AppError.notFound }

        // Insert splits
        let splitInserts = splits.map { split in
            PaymentSplitInsert(
                paymentRequestID: request.id,
                userID: split.userID,
                amount: split.amount
            )
        }
        let insertedSplits: [PaymentSplit] = try await supabase
            .from("payment_splits")
            .insert(splitInserts)
            .select("*, user:users(*)")
            .execute()
            .value
        request.splits = insertedSplits
        return request
    }

    // MARK: - Mark Paid

    /// Mark a split as paid (called after user confirms payment).
    func markPaid(splitID: UUID) async throws {
        try await supabase
            .from("payment_splits")
            .update(["is_paid": true])
            .eq("id", value: splitID)
            .execute()
    }

    // MARK: - Fetch

    /// Fetch payment request for a post.
    func fetchRequest(for postID: UUID) async throws -> PaymentRequest? {
        let requests: [PaymentRequest] = try await supabase
            .from("payment_requests")
            .select("*, splits:payment_splits(*, user:users(*))")
            .eq("post_id", value: postID)
            .execute()
            .value
        return requests.first
    }

    // MARK: - Deep Links

    /// Generate Venmo deep link.
    /// Format: venmo://paycharge?txn=pay&recipients=USERNAME&amount=AMOUNT&note=NOTE
    /// Falls back to https://venmo.com if the app is not installed.
    func venmoDeepLink(to username: String, amount: Double, note: String) -> URL {
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? note
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let amountString = String(format: "%.2f", amount)

        let deepLinkString = "venmo://paycharge?txn=pay&recipients=\(encodedUsername)&amount=\(amountString)&note=\(encodedNote)"
        if let url = URL(string: deepLinkString) {
            return url
        }
        // Fallback to web
        return URL(string: "https://venmo.com/\(encodedUsername)")!
    }

    /// Generate PayPal deep link.
    /// Format: paypal://paypalme/USERNAME/AMOUNT
    func paypalDeepLink(to username: String, amount: Double) -> URL {
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let amountString = String(format: "%.2f", amount)
        let deepLinkString = "paypal://paypalme/\(encodedUsername)/\(amountString)"
        if let url = URL(string: deepLinkString) {
            return url
        }
        // Fallback to web
        return URL(string: "https://www.paypal.me/\(encodedUsername)/\(amountString)")!
    }
}

// MARK: - Private Encodable types

private struct PaymentRequestInsert: Encodable {
    let postID: UUID
    let homeID: UUID
    let requestorID: UUID
    let totalAmount: Double
    let note: String

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case homeID = "home_id"
        case requestorID = "requestor_id"
        case totalAmount = "total_amount"
        case note
    }
}

private struct PaymentSplitInsert: Encodable {
    let paymentRequestID: UUID
    let userID: UUID
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case paymentRequestID = "payment_request_id"
        case userID = "user_id"
        case amount
    }
}
