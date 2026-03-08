import Supabase
import Foundation

/// Manages homes — creation, joining, fetching members
class HomeService {
    static let shared = HomeService()
    private init() {}

    func createHome(name: String, ownerID: UUID) async throws -> Home {
        let inviteCode = String(UUID().uuidString.prefix(8).uppercased())
        let insert = HomeInsert(name: name, ownerID: ownerID, inviteCode: inviteCode)
        let homes: [Home] = try await supabase
            .from("homes")
            .insert(insert)
            .select()
            .execute()
            .value
        guard let home = homes.first else { throw AppError.notFound }

        // Owner is also a member
        try await joinHome(homeID: home.id, userID: ownerID)
        return home
    }

    func joinHomeByCode(_ code: String, userID: UUID) async throws -> Home {
        let homes: [Home] = try await supabase
            .from("homes")
            .select()
            .eq("invite_code", value: code.uppercased())
            .limit(1)
            .execute()
            .value
        guard let home = homes.first else { throw AppError.notFound }
        try await joinHome(homeID: home.id, userID: userID)
        return home
    }

    func joinHome(homeID: UUID, userID: UUID) async throws {
        let membership = HomeMembership(homeID: homeID, userID: userID)
        try await supabase.from("home_members").insert(membership).execute()
    }

    // Fetch all homes the current user belongs to
    func fetchHomes(for userID: UUID) async throws -> [Home] {
        let homes: [Home] = try await supabase
            .from("home_members")
            .select("homes(*)")
            .eq("user_id", value: userID)
            .execute()
            .value
        return homes
    }

    func fetchMembers(for homeID: UUID) async throws -> [User] {
        let members: [User] = try await supabase
            .from("home_members")
            .select("users(*)")
            .eq("home_id", value: homeID)
            .execute()
            .value
        return members
    }
}

private struct HomeInsert: Encodable {
    let name: String
    let ownerID: UUID
    let inviteCode: String
    enum CodingKeys: String, CodingKey {
        case name
        case ownerID = "owner_id"
        case inviteCode = "invite_code"
    }
}

private struct HomeMembership: Encodable {
    let homeID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case userID = "user_id"
    }
}
