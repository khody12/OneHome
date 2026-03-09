import Foundation

/// A recurring shared expense for a home (Netflix, Spotify, etc.)
/// Applies to a configurable subset of roommates.
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

/// Pre-loaded list of popular subscription services
struct PopularService: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

let popularServices: [PopularService] = [
    PopularService(name: "Custom", icon: "✏️"),
    PopularService(name: "Netflix", icon: "📺"),
    PopularService(name: "Spotify", icon: "🎵"),
    PopularService(name: "HBO Max", icon: "🎬"),
    PopularService(name: "Disney+", icon: "🏰"),
    PopularService(name: "Hulu", icon: "📡"),
    PopularService(name: "Apple TV+", icon: "🍎"),
    PopularService(name: "Amazon Prime", icon: "📦"),
    PopularService(name: "YouTube Premium", icon: "▶️"),
    PopularService(name: "Apple Music", icon: "🎶"),
    PopularService(name: "Peacock", icon: "🦚"),
    PopularService(name: "Paramount+", icon: "⭐"),
    PopularService(name: "ESPN+", icon: "🏈"),
    PopularService(name: "Xbox Game Pass", icon: "🎮"),
    PopularService(name: "PlayStation Plus", icon: "🕹️"),
    PopularService(name: "Nintendo Switch Online", icon: "👾"),
    PopularService(name: "iCloud+", icon: "☁️"),
    PopularService(name: "Google One", icon: "🔵"),
    PopularService(name: "Dropbox", icon: "📁"),
    PopularService(name: "ChatGPT Plus", icon: "🤖"),
    PopularService(name: "Adobe Creative Cloud", icon: "🎨"),
]
