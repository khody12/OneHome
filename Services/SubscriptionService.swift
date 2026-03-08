import Supabase
import Foundation

/// Manages shared home subscriptions (Netflix, Spotify, etc.)
class SubscriptionService {
    static let shared = SubscriptionService()
    private init() {}

    func fetchSubscriptions(for homeID: UUID) async throws -> [Subscription] {
        let subs: [Subscription] = try await supabase
            .from("subscriptions")
            .select("*, members:subscription_members(*, user:users(*))")
            .eq("home_id", value: homeID)
            .order("created_at", ascending: false)
            .execute()
            .value
        return subs
    }

    func createSubscription(_ sub: Subscription, memberIDs: [UUID]) async throws -> Subscription {
        let insert = SubscriptionInsert(
            homeID: sub.homeID,
            createdByID: sub.createdByID,
            serviceName: sub.serviceName,
            serviceIcon: sub.serviceIcon,
            monthlyCost: sub.monthlyCost,
            billingDay: sub.billingDay
        )
        let created: [Subscription] = try await supabase
            .from("subscriptions")
            .insert(insert)
            .select("*, members:subscription_members(*, user:users(*))")
            .execute()
            .value
        guard let newSub = created.first else { throw AppError.notFound }

        // Insert members
        let memberInserts = memberIDs.map { userID in
            SubscriptionMemberInsert(subscriptionID: newSub.id, userID: userID)
        }
        if !memberInserts.isEmpty {
            try await supabase
                .from("subscription_members")
                .insert(memberInserts)
                .execute()
        }

        // Re-fetch with populated members
        let refreshed: [Subscription] = try await supabase
            .from("subscriptions")
            .select("*, members:subscription_members(*, user:users(*))")
            .eq("id", value: newSub.id)
            .limit(1)
            .execute()
            .value
        return refreshed.first ?? newSub
    }

    func deleteSubscription(id: UUID) async throws {
        try await supabase
            .from("subscriptions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateSubscription(_ sub: Subscription) async throws {
        let update = SubscriptionUpdate(
            serviceName: sub.serviceName,
            serviceIcon: sub.serviceIcon,
            monthlyCost: sub.monthlyCost,
            billingDay: sub.billingDay
        )
        try await supabase
            .from("subscriptions")
            .update(update)
            .eq("id", value: sub.id)
            .execute()
    }
}

// MARK: - Private Encodable types

private struct SubscriptionInsert: Encodable {
    let homeID: UUID
    let createdByID: UUID
    let serviceName: String
    let serviceIcon: String
    let monthlyCost: Double
    let billingDay: Int

    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case createdByID = "created_by_id"
        case serviceName = "service_name"
        case serviceIcon = "service_icon"
        case monthlyCost = "monthly_cost"
        case billingDay = "billing_day"
    }
}

private struct SubscriptionUpdate: Encodable {
    let serviceName: String
    let serviceIcon: String
    let monthlyCost: Double
    let billingDay: Int

    enum CodingKeys: String, CodingKey {
        case serviceName = "service_name"
        case serviceIcon = "service_icon"
        case monthlyCost = "monthly_cost"
        case billingDay = "billing_day"
    }
}

private struct SubscriptionMemberInsert: Encodable {
    let subscriptionID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case subscriptionID = "subscription_id"
        case userID = "user_id"
    }
}
