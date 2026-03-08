import Foundation

// A recurring shared expense for a home (Netflix, Spotify, etc.)
// Only applies to a subset of roommates, not necessarily all.
struct Subscription: Codable, Identifiable {
    let id: UUID
    let homeID: UUID
    let createdByID: UUID
    var serviceName: String       // "Netflix", "Spotify", etc.
    var serviceIcon: String       // emoji or SF Symbol name
    var monthlyCost: Double
    var billingDay: Int           // day of month (1-28)
    var members: [SubscriptionMember]  // who is on this sub
    let createdAt: Date

    // Computed: cost per active member
    var costPerMember: Double {
        guard !members.isEmpty else { return monthlyCost }
        return (monthlyCost / Double(members.count) * 100).rounded() / 100
    }

    enum CodingKeys: String, CodingKey {
        case id, members
        case homeID = "home_id"
        case createdByID = "created_by_id"
        case serviceName = "service_name"
        case serviceIcon = "service_icon"
        case monthlyCost = "monthly_cost"
        case billingDay = "billing_day"
        case createdAt = "created_at"
    }
}

struct SubscriptionMember: Codable, Identifiable {
    let id: UUID
    let subscriptionID: UUID
    let userID: UUID
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionID = "subscription_id"
        case userID = "user_id"
        case user
    }
}
