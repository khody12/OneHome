import Foundation

// Home model — one user can own multiple homes, many members
struct Home: Codable, Identifiable {
    let id: UUID
    var name: String
    let ownerID: UUID
    let createdAt: Date
    var inviteCode: String  // short code owner shares to invite people
    var members: [User]?    // populated via join

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerID = "owner_id"
        case createdAt = "created_at"
        case inviteCode = "invite_code"
        case members
    }
}
