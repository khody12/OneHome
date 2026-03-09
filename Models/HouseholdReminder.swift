import Foundation

struct HouseholdReminder: Codable, Identifiable {
    var id: UUID
    var homeID: UUID
    var name: String
    var emoji: String
    var intervalDays: Int
    var lastClearedAt: Date?
    var lastClearedByUserID: UUID?
    var lastClearedByUser: User?
    var createdAt: Date
    var createdByUserID: UUID
    var currentClaimerID: UUID?       // who locked "I'll grab it" for this cycle
    var currentClaimerUser: User?     // joined
    var grabs: [ReminderGrab]?        // full grab history, joined

    enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case homeID = "home_id"
        case intervalDays = "interval_days"
        case lastClearedAt = "last_cleared_at"
        case lastClearedByUserID = "last_cleared_by_user_id"
        case lastClearedByUser = "last_cleared_by_user"
        case createdAt = "created_at"
        case createdByUserID = "created_by_user_id"
        case currentClaimerID = "current_claimer_id"
        case currentClaimerUser = "current_claimer_user"
        case grabs
    }

    // MARK: - Computed helpers

    /// The next time this reminder is due, nil if never cleared
    var nextDueAt: Date? {
        guard let cleared = lastClearedAt else { return nil }
        return cleared.addingTimeInterval(Double(intervalDays) * 86400)
    }

    /// Whether this reminder should show a system post in the feed
    var isActiveInFeed: Bool {
        isDue || currentClaimerID != nil
    }

    /// Whether this reminder needs attention right now
    var isDue: Bool {
        guard let due = nextDueAt else { return true }
        return due <= Date()
    }

    /// How many full days past due (0 if not overdue)
    var daysOverdue: Int {
        guard isDue, let due = nextDueAt else { return 0 }
        let seconds = Date().timeIntervalSince(due)
        return max(0, Int(seconds / 86400))
    }

    /// Human-readable status label
    var statusLabel: String {
        guard let due = nextDueAt else {
            return "Never bought"
        }
        let now = Date()
        if due <= now {
            let days = daysOverdue
            if days == 0 {
                return "Due now"
            }
            return "\(days) day\(days == 1 ? "" : "s") overdue"
        } else {
            let secondsUntilDue = due.timeIntervalSince(now)
            let daysUntilDue = Int(secondsUntilDue / 86400)
            if daysUntilDue == 0 {
                return "Due today"
            }
            return "Due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")"
        }
    }
}
