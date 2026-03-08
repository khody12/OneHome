import Foundation

struct Comment: Codable, Identifiable {
    let id: UUID
    let postID: UUID
    let userID: UUID
    var text: String
    let createdAt: Date
    var author: User?

    enum CodingKeys: String, CodingKey {
        case id, text
        case postID = "post_id"
        case userID = "user_id"
        case createdAt = "created_at"
        case author
    }
}
