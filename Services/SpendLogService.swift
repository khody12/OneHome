import Supabase
import Foundation

/// Manages manual spend log entries for a home
class SpendLogService {
    static let shared = SpendLogService()
    private init() {}

    func fetchLogs(for homeID: UUID) async throws -> [SpendLog] {
        let logs: [SpendLog] = try await supabase
            .from("spend_logs")
            .select("*, user:users(*)")
            .eq("home_id", value: homeID)
            .order("created_at", ascending: false)
            .execute()
            .value
        return logs
    }

    func logSpend(homeID: UUID, userID: UUID, amount: Double, category: SpendCategory, note: String) async throws -> SpendLog {
        let insert = SpendLogInsert(
            homeID: homeID,
            userID: userID,
            amount: amount,
            category: category.rawValue,
            note: note
        )
        let logs: [SpendLog] = try await supabase
            .from("spend_logs")
            .insert(insert)
            .select("*, user:users(*)")
            .execute()
            .value
        guard let log = logs.first else { throw AppError.notFound }
        return log
    }

    func deleteLog(id: UUID) async throws {
        try await supabase
            .from("spend_logs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // Totals by category
    func totalByCategory(logs: [SpendLog]) -> [SpendCategory: Double] {
        Dictionary(grouping: logs, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    // Totals by user
    func totalByUser(logs: [SpendLog]) -> [UUID: Double] {
        Dictionary(grouping: logs, by: \.userID)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }
}

// MARK: - Private Encodable types

private struct SpendLogInsert: Encodable {
    let homeID: UUID
    let userID: UUID
    let amount: Double
    let category: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case userID = "user_id"
        case amount, category, note
    }
}
