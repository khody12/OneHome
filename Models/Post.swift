import Foundation

// Single post type with category. Kudos-only (no likes).
// Draft feature: post is saved to DB immediately on creation start.

enum PostCategory: String, Codable, CaseIterable {
    case chore = "chore"
    case purchase = "purchase"
    case general = "general"

    var emoji: String {
        switch self {
        case .chore: return "🧹"
        case .purchase: return "🛒"
        case .general: return "📣"
        }
    }

    var label: String {
        switch self {
        case .chore: return "Chore"
        case .purchase: return "Purchase"
        case .general: return "General"
        }
    }
}

struct Post: Codable, Identifiable {
    let id: UUID
    let homeID: UUID
    let userID: UUID
    var category: PostCategory
    var text: String
    var imageURL: String?
    var isDraft: Bool
    let createdAt: Date
    var kudosCount: Int
    var comments: [Comment]?
    var author: User?         // populated via join
    var hasGivenKudos: Bool = false  // local state for current user
    var paymentRequest: PaymentRequest?  // populated via join for purchase posts

    enum CodingKeys: String, CodingKey {
        case id, category, text
        case homeID = "home_id"
        case userID = "user_id"
        case imageURL = "image_url"
        case isDraft = "is_draft"
        case createdAt = "created_at"
        case kudosCount = "kudos_count"
        case comments, author
        case paymentRequest = "payment_request"
    }
}
