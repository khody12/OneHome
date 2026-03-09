import Foundation

struct ReminderGrab: Codable, Identifiable {
    var id: UUID
    var reminderID: UUID
    var userID: UUID
    var grabbedAt: Date
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id
        case reminderID = "reminder_id"
        case userID = "user_id"
        case grabbedAt = "grabbed_at"
        case user
    }
}
