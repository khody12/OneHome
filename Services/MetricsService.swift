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

    // MARK: - Leaderboards

    /// Count of chore posts per user for a specific subcategory (optionally since a date).
    func fetchChoreLeaderboard(homeID: UUID, subcategory: ChoreSubcategory, since: Date?) async throws -> [CategoryLeaderboardEntry] {
        // Raw rows returned: user_id, count, user
        struct Row: Decodable {
            let userID: UUID
            let count: Int
            let user: User

            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case count
                case user
            }
        }

        var query = supabase
            .from("posts")
            .select("user_id, user:users(*)")
            .eq("home_id", value: homeID)
            .eq("category", value: PostCategory.chore.rawValue)
            .eq("is_draft", value: false)
            .eq("chore_subcategory", value: subcategory.rawValue)

        if let since {
            query = query.gte("created_at", value: ISO8601DateFormatter().string(from: since))
        }

        // We aggregate client-side since Supabase JS SDK group-by is verbose via Swift
        struct RawPost: Decodable {
            let userID: UUID
            let user: User
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case user
            }
        }
        let rows: [RawPost] = try await query.execute().value

        // Group by userID
        var countMap: [UUID: (user: User, count: Int)] = [:]
        for row in rows {
            if var existing = countMap[row.userID] {
                existing.count += 1
                countMap[row.userID] = existing
            } else {
                countMap[row.userID] = (user: row.user, count: 1)
            }
        }

        return countMap.map { id, val in
            CategoryLeaderboardEntry(id: id, user: val.user, count: val.count, totalAmount: 0)
        }.sorted { $0.count > $1.count }
    }

    /// Total chore posts per user across all subcategories (optionally since a date).
    func fetchOverallChoreLeaderboard(homeID: UUID, since: Date?) async throws -> [CategoryLeaderboardEntry] {
        struct RawPost: Decodable {
            let userID: UUID
            let user: User
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case user
            }
        }

        var query = supabase
            .from("posts")
            .select("user_id, user:users(*)")
            .eq("home_id", value: homeID)
            .eq("category", value: PostCategory.chore.rawValue)
            .eq("is_draft", value: false)

        if let since {
            query = query.gte("created_at", value: ISO8601DateFormatter().string(from: since))
        }

        let rows: [RawPost] = try await query.execute().value

        var countMap: [UUID: (user: User, count: Int)] = [:]
        for row in rows {
            if var existing = countMap[row.userID] {
                existing.count += 1
                countMap[row.userID] = existing
            } else {
                countMap[row.userID] = (user: row.user, count: 1)
            }
        }

        return countMap.map { id, val in
            CategoryLeaderboardEntry(id: id, user: val.user, count: val.count, totalAmount: 0)
        }.sorted { $0.count > $1.count }
    }

    /// Total amount spent per user from purchase posts (optionally since a date).
    func fetchSpendLeaderboard(homeID: UUID, since: Date?) async throws -> [CategoryLeaderboardEntry] {
        struct RawPost: Decodable {
            let userID: UUID
            let user: User
            let paymentRequest: PaymentRequest?
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case user
                case paymentRequest = "payment_request"
            }
        }

        var query = supabase
            .from("posts")
            .select("user_id, user:users(*), payment_request:payment_requests(*)")
            .eq("home_id", value: homeID)
            .eq("category", value: PostCategory.purchase.rawValue)
            .eq("is_draft", value: false)

        if let since {
            query = query.gte("created_at", value: ISO8601DateFormatter().string(from: since))
        }

        let rows: [RawPost] = try await query.execute().value

        var amountMap: [UUID: (user: User, total: Double)] = [:]
        for row in rows {
            let amount = row.paymentRequest?.totalAmount ?? 0
            if var existing = amountMap[row.userID] {
                existing.total += amount
                amountMap[row.userID] = existing
            } else {
                amountMap[row.userID] = (user: row.user, total: amount)
            }
        }

        return amountMap.map { id, val in
            CategoryLeaderboardEntry(id: id, user: val.user, count: 0, totalAmount: val.total)
        }.sorted { $0.totalAmount > $1.totalAmount }
    }
}
