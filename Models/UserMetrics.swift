import Foundation

// Per-user, per-home contribution metrics
struct UserMetrics: Codable, Identifiable {
    let id: UUID
    let userID: UUID
    let homeID: UUID
    var choresDone: Int
    var totalSpent: Double
    var lastPostAt: Date?
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case homeID = "home_id"
        case choresDone = "chores_done"
        case totalSpent = "total_spent"
        case lastPostAt = "last_post_at"
        case user
    }

    // True if this user is slacking — hasn't posted in 72h while others have
    func isSlacking(comparedTo metrics: [UserMetrics]) -> Bool {
        guard let lastPost = lastPostAt else { return true }
        let cutoff = Date().addingTimeInterval(-72 * 3600)
        let othersActive = metrics.filter { $0.userID != userID }
            .contains { ($0.lastPostAt ?? .distantPast) > cutoff }
        return othersActive && lastPost < cutoff
    }
}
