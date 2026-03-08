import Supabase
import Foundation

/// Handles ephemeral sticky notes (48h TTL)
class StickyNoteService {
    static let shared = StickyNoteService()
    private init() {}

    func post(text: String, homeID: UUID, userID: UUID) async throws -> StickyNote {
        let expiresAt = Date().addingTimeInterval(48 * 3600)
        let insert = StickyNoteInsert(homeID: homeID, userID: userID, text: text, expiresAt: expiresAt)
        let notes: [StickyNote] = try await supabase
            .from("sticky_notes")
            .insert(insert)
            .select("*, author:users(*)")
            .execute()
            .value
        guard let note = notes.first else { throw AppError.notFound }
        return note
    }

    // Fetch non-expired sticky notes for a home
    func fetchActive(for homeID: UUID) async throws -> [StickyNote] {
        let now = ISO8601DateFormatter().string(from: Date())
        let notes: [StickyNote] = try await supabase
            .from("sticky_notes")
            .select("*, author:users(*)")
            .eq("home_id", value: homeID)
            .gt("expires_at", value: now)
            .order("created_at", ascending: false)
            .execute()
            .value
        return notes
    }

    func delete(noteID: UUID) async throws {
        try await supabase.from("sticky_notes").delete().eq("id", value: noteID).execute()
    }
}

private struct StickyNoteInsert: Encodable {
    let homeID: UUID
    let userID: UUID
    let text: String
    let expiresAt: Date
    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case userID = "user_id"
        case text
        case expiresAt = "expires_at"
    }
}
