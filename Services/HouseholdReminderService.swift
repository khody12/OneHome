import Supabase
import Foundation

/// Manages household item reminders for a home
class HouseholdReminderService {
    static let shared = HouseholdReminderService()
    private init() {}

    func fetchReminders(for homeID: UUID) async throws -> [HouseholdReminder] {
        let reminders: [HouseholdReminder] = try await supabase
            .from("household_reminders")
            .select("""
                *,
                last_cleared_by_user:users!last_cleared_by_user_id(*),
                current_claimer_user:users!current_claimer_id(*),
                grabs:reminder_grabs(*, user:users(*))
                """)
            .eq("home_id", value: homeID)
            .order("created_at", ascending: false)
            .execute()
            .value
        return reminders
    }

    func fetchGrabs(for reminderID: UUID) async throws -> [ReminderGrab] {
        let grabs: [ReminderGrab] = try await supabase
            .from("reminder_grabs")
            .select("*, user:users(*)")
            .eq("reminder_id", value: reminderID)
            .order("grabbed_at", ascending: false)
            .execute()
            .value
        return grabs
    }

    func createReminder(homeID: UUID, userID: UUID, name: String, emoji: String, intervalDays: Int) async throws -> HouseholdReminder {
        let insert = HouseholdReminderInsert(
            homeID: homeID,
            createdByUserID: userID,
            name: name,
            emoji: emoji,
            intervalDays: intervalDays
        )
        let reminders: [HouseholdReminder] = try await supabase
            .from("household_reminders")
            .insert(insert)
            .select("*, last_cleared_by_user:users!last_cleared_by_user_id(*)")
            .execute()
            .value
        guard let reminder = reminders.first else { throw AppError.notFound }
        return reminder
    }

    /// Called from YourHomeView to manually clear a reminder (no grab record).
    func clearReminder(id: UUID, byUserID: UUID) async throws {
        let update = HouseholdReminderClear(
            lastClearedAt: Date(),
            lastClearedByUserID: byUserID,
            currentClaimerID: nil
        )
        try await supabase
            .from("household_reminders")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    /// Called from feed "I'll grab it" — sets claimer, resets timer, records grab history.
    func claimReminder(id: UUID, byUserID: UUID) async throws {
        let update = HouseholdReminderClaim(
            lastClearedAt: Date(),
            lastClearedByUserID: byUserID,
            currentClaimerID: byUserID
        )
        try await supabase
            .from("household_reminders")
            .update(update)
            .eq("id", value: id)
            .execute()
        let grab = ReminderGrabInsert(reminderID: id, userID: byUserID)
        try await supabase
            .from("reminder_grabs")
            .insert(grab)
            .execute()
    }

    func deleteReminder(id: UUID) async throws {
        try await supabase
            .from("household_reminders")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Private Encodable types

private struct HouseholdReminderInsert: Encodable {
    let homeID: UUID
    let createdByUserID: UUID
    let name: String
    let emoji: String
    let intervalDays: Int

    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case createdByUserID = "created_by_user_id"
        case name, emoji
        case intervalDays = "interval_days"
    }
}

private struct HouseholdReminderClear: Encodable {
    let lastClearedAt: Date
    let lastClearedByUserID: UUID
    let currentClaimerID: UUID?

    enum CodingKeys: String, CodingKey {
        case lastClearedAt = "last_cleared_at"
        case lastClearedByUserID = "last_cleared_by_user_id"
        case currentClaimerID = "current_claimer_id"
    }
}

private struct HouseholdReminderClaim: Encodable {
    let lastClearedAt: Date
    let lastClearedByUserID: UUID
    let currentClaimerID: UUID

    enum CodingKeys: String, CodingKey {
        case lastClearedAt = "last_cleared_at"
        case lastClearedByUserID = "last_cleared_by_user_id"
        case currentClaimerID = "current_claimer_id"
    }
}

private struct ReminderGrabInsert: Encodable {
    let reminderID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case reminderID = "reminder_id"
        case userID = "user_id"
    }
}
