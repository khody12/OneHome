import Foundation

/// Manages invitations — by username, by invite code, and pending invites
class InviteService {
    static let shared = InviteService()
    private init() {}

    // Invite a user by username to a home (owner only).
    // Creates a pending_invites row; the invitee sees it on next app open.
    func inviteByUsername(_ username: String, to homeID: UUID, from inviterID: UUID) async throws {
        let users: [User] = try await supabase
            .from("users")
            .select()
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value
        guard let invitee = users.first else { throw AppError.notFound }
        let invite = PendingInviteInsert(homeID: homeID, inviteeID: invitee.id, inviterID: inviterID)
        try await supabase.from("pending_invites").insert(invite).execute()
    }

    // Fetch pending invites for the current user
    func fetchPendingInvites(for userID: UUID) async throws -> [PendingInvite] {
        let invites: [PendingInvite] = try await supabase
            .from("pending_invites")
            .select("*, home:homes(*), inviter:users!inviter_id(*)")
            .eq("invitee_id", value: userID)
            .eq("status", value: "pending")
            .execute()
            .value
        return invites
    }

    // Accept an invite — joins the home, marks invite accepted
    func accept(invite: PendingInvite, userID: UUID) async throws {
        try await HomeService.shared.joinHome(homeID: invite.homeID, userID: userID)
        try await supabase
            .from("pending_invites")
            .update(["status": "accepted"])
            .eq("id", value: invite.id)
            .execute()
    }

    // Decline an invite
    func decline(invite: PendingInvite) async throws {
        try await supabase
            .from("pending_invites")
            .update(["status": "declined"])
            .eq("id", value: invite.id)
            .execute()
    }
}

// MARK: - Models

struct PendingInvite: Codable, Identifiable {
    let id: UUID
    let homeID: UUID
    let inviteeID: UUID
    let inviterID: UUID
    var status: String  // "pending" | "accepted" | "declined"
    let createdAt: Date
    var home: Home?
    var inviter: User?

    enum CodingKeys: String, CodingKey {
        case id, status
        case homeID = "home_id"
        case inviteeID = "invitee_id"
        case inviterID = "inviter_id"
        case createdAt = "created_at"
        case home, inviter
    }
}

private struct PendingInviteInsert: Encodable {
    let homeID: UUID
    let inviteeID: UUID
    let inviterID: UUID
    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case inviteeID = "invitee_id"
        case inviterID = "inviter_id"
    }
}
