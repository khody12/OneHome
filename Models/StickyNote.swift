import Foundation

// Ephemeral message — expires 48h after creation, not stored permanently
struct StickyNote: Codable, Identifiable {
    let id: UUID
    let homeID: UUID
    let userID: UUID
    var text: String
    let createdAt: Date
    let expiresAt: Date
    var author: User?

    // Whether this note has expired
    var isExpired: Bool { Date() > expiresAt }

    enum CodingKeys: String, CodingKey {
        case id, text
        case homeID = "home_id"
        case userID = "user_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case author
    }
}
