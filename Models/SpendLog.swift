import Foundation

// A manual spend entry — logged without making a full post.
// Also, purchase posts contribute to this automatically via DB trigger.
struct SpendLog: Codable, Identifiable {
    let id: UUID
    let homeID: UUID
    let userID: UUID
    var amount: Double
    var category: SpendCategory
    var note: String
    let createdAt: Date
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id, amount, note
        case homeID = "home_id"
        case userID = "user_id"
        case category
        case createdAt = "created_at"
        case user
    }
}

enum SpendCategory: String, Codable, CaseIterable {
    case food = "food"
    case household = "household"
    case utilities = "utilities"
    case entertainment = "entertainment"
    case other = "other"

    var emoji: String {
        switch self {
        case .food: return "🍕"
        case .household: return "🧹"
        case .utilities: return "💡"
        case .entertainment: return "🎮"
        case .other: return "📦"
        }
    }

    var label: String {
        switch self {
        case .food: return "Food"
        case .household: return "Household"
        case .utilities: return "Utilities"
        case .entertainment: return "Entertainment"
        case .other: return "Other"
        }
    }
}
