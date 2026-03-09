import Foundation

struct Reaction: Codable, Identifiable {
    let id: UUID
    let postID: UUID
    let userID: UUID
    let emoji: String
    let createdAt: Date
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id, emoji
        case postID = "post_id"
        case userID = "user_id"
        case createdAt = "created_at"
        case user
    }
}

let presetReactions: [String] = [
    "🐐", "👍", "❤️", "💯", "🔥", "😂", "😮", "😢", "👏",
    "🙌", "💪", "🫡", "🤩", "💀", "🫶", "⭐", "🎉", "👀", "🤝", "💅"
]
