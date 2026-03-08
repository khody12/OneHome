import Supabase
import Foundation

/// Fetches and updates user contribution metrics per home
class MetricsService {
    static let shared = MetricsService()
    private init() {}

    func fetchMetrics(for homeID: UUID) async throws -> [UserMetrics] {
        let metrics: [UserMetrics] = try await supabase
            .from("user_metrics")
            .select("*, user:users(*)")
            .eq("home_id", value: homeID)
            .execute()
            .value
        return metrics
    }

    // Call when a post is published — bumps chores_done or notes total_spent
    func recordPost(userID: UUID, homeID: UUID, category: PostCategory, amount: Double = 0) async throws {
        // Upsert metrics row
        let now = ISO8601DateFormatter().string(from: Date())
        if category == .chore {
            try await supabase.rpc("increment_chores", params: [
                "p_user_id": userID.uuidString,
                "p_home_id": homeID.uuidString,
                "p_last_post": now
            ]).execute()
        } else if category == .purchase {
            try await supabase.rpc("increment_spent", params: [
                "p_user_id": userID.uuidString,
                "p_home_id": homeID.uuidString,
                "p_amount": String(amount),
                "p_last_post": now
            ]).execute()
        } else {
            try await supabase.rpc("update_last_post", params: [
                "p_user_id": userID.uuidString,
                "p_home_id": homeID.uuidString,
                "p_last_post": now
            ]).execute()
        }
    }
}
