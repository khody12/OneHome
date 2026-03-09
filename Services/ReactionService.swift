import Supabase
import Foundation

/// Handles emoji reactions on posts via the post_reactions table
class ReactionService {
    static let shared = ReactionService()
    private init() {}

    func addReaction(postID: UUID, userID: UUID, emoji: String) async throws -> Reaction {
        let insert = ReactionInsert(postID: postID, userID: userID, emoji: emoji)
        let reactions: [Reaction] = try await supabase
            .from("post_reactions")
            .insert(insert)
            .select("*, user:users(*)")
            .execute()
            .value
        guard let reaction = reactions.first else { throw AppError.notFound }
        return reaction
    }

    func removeReaction(id: UUID) async throws {
        try await supabase
            .from("post_reactions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func fetchReactions(for postID: UUID) async throws -> [Reaction] {
        let reactions: [Reaction] = try await supabase
            .from("post_reactions")
            .select("*, user:users(*)")
            .eq("post_id", value: postID)
            .order("created_at", ascending: true)
            .execute()
            .value
        return reactions
    }
}

private struct ReactionInsert: Encodable {
    let postID: UUID
    let userID: UUID
    let emoji: String
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case emoji
    }
}
