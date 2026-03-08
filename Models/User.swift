import Foundation

// User model — Codable for Supabase, Identifiable
struct User: Codable, Identifiable {
    let id: UUID
    var username: String
    var name: String
    var email: String
    var avatarURL: String?
    let createdAt: Date
    var venmoUsername: String?
    var paypalUsername: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, email
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case venmoUsername = "venmo_username"
        case paypalUsername = "paypal_username"
    }
}
