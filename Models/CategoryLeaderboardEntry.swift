import Foundation

// MARK: - CategoryLeaderboardEntry
//
// A single row in a chore or spend leaderboard.

struct CategoryLeaderboardEntry: Identifiable {
    var id: UUID      // userID
    var user: User
    var count: Int         // for chore-based boards
    var totalAmount: Double  // for spend-based boards
}
