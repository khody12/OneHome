import Foundation

// Single post type with category. Emoji reactions (no likes/kudos).
// Draft feature: post is saved to DB immediately on creation start.

// MARK: - ChoreSubcategory

enum ChoreSubcategory: String, Codable, CaseIterable, Identifiable {
    case cooking = "cooking"
    case dishes = "dishes"
    case floors = "floors"
    case laundry = "laundry"
    case trash = "trash"
    case groceries = "groceries"
    case bathrooms = "bathrooms"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cooking:   return "Cooking"
        case .dishes:    return "Dishes"
        case .floors:    return "Floors"
        case .laundry:   return "Laundry"
        case .trash:     return "Trash"
        case .groceries: return "Groceries"
        case .bathrooms: return "Bathrooms"
        case .other:     return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .cooking:   return "🍳"
        case .dishes:    return "🍽️"
        case .floors:    return "🧹"
        case .laundry:   return "👕"
        case .trash:     return "🗑️"
        case .groceries: return "🛒"
        case .bathrooms: return "🚿"
        case .other:     return "📦"
        }
    }
}

// MARK: - PostCategory

enum PostCategory: String, Codable, CaseIterable {
    case chore = "chore"
    case purchase = "purchase"
    case general = "general"
    case request = "request"

    var emoji: String {
        switch self {
        case .chore: return "🧹"
        case .purchase: return "🛒"
        case .general: return "📣"
        case .request: return "🙋"
        }
    }

    var label: String {
        switch self {
        case .chore: return "Chore"
        case .purchase: return "Purchase"
        case .general: return "General"
        case .request: return "Request"
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
    var reactions: [Reaction]?
    var comments: [Comment]?
    var author: User?         // populated via join
    var paymentRequest: PaymentRequest?  // populated via join for purchase posts
    var requestedUserIDs: [UUID]?       // nil = open to everyone; set = specific roommates
    var completionPostID: UUID?         // UUID of the post that completed this request
    var choreSubcategory: ChoreSubcategory?  // only set when category == .chore

    // Synthetic fields for home system posts — not persisted to DB, not in CodingKeys
    var isSystemPost: Bool = false
    var reminderID: UUID? = nil
    var reminder: HouseholdReminder? = nil   // full reminder for detail view + claimer state
    var homeMembers: [User]? = nil           // for "who hasn't grabbed it" avatar row

    enum CodingKeys: String, CodingKey {
        case id, category, text
        case homeID = "home_id"
        case userID = "user_id"
        case imageURL = "image_url"
        case isDraft = "is_draft"
        case createdAt = "created_at"
        case reactions, comments, author
        case paymentRequest = "payment_request"
        case requestedUserIDs = "requested_user_ids"
        case completionPostID = "completion_post_id"
        case choreSubcategory = "chore_subcategory"
    }
}
