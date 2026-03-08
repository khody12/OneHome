import Foundation

// A payment request attached to a purchase post.
// Tracks which roommates owe money and whether they've paid.
struct PaymentRequest: Codable, Identifiable {
    let id: UUID
    let postID: UUID
    let homeID: UUID
    let requestorID: UUID       // who is owed money
    let totalAmount: Double     // full purchase amount
    let note: String            // e.g. "Groceries run 🛒"
    let createdAt: Date
    var splits: [PaymentSplit]  // one per person who owes

    enum CodingKeys: String, CodingKey {
        case id, note
        case postID = "post_id"
        case homeID = "home_id"
        case requestorID = "requestor_id"
        case totalAmount = "total_amount"
        case createdAt = "created_at"
        case splits
    }

    // Convenience computed properties
    var paidCount: Int { splits.filter { $0.isPaid }.count }
    var pendingCount: Int { splits.filter { !$0.isPaid }.count }
}

struct PaymentSplit: Codable, Identifiable {
    let id: UUID
    let paymentRequestID: UUID
    let userID: UUID
    var amount: Double
    var isPaid: Bool
    let createdAt: Date
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id, amount
        case paymentRequestID = "payment_request_id"
        case userID = "user_id"
        case isPaid = "is_paid"
        case createdAt = "created_at"
        case user
    }
}
