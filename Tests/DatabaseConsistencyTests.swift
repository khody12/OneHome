import Testing
import Foundation
@testable import OneHome

// MARK: - DatabaseConsistencyTests
//
// Pure Swift logic tests that verify our Codable models produce JSON keys
// matching the column names defined in schema.sql. No network calls.
// Uses iso8601 date encoding to match Supabase's timestamptz format.

private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}()

private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

private func jsonKeys(from encodable: some Encodable) throws -> [String: Any] {
    let data = try encoder.encode(encodable)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

@Suite("Database Consistency")
struct DatabaseConsistencyTests {

    // MARK: - User

    @Test("User coding keys match schema columns")
    func userCodingKeysMatchSchema() throws {
        // Schema: id, username, name, email, avatar_url, created_at
        let user = Fake.user()
        let json = try jsonKeys(from: user)

        #expect(json["id"] != nil)
        #expect(json["username"] != nil)
        #expect(json["name"] != nil)
        #expect(json["email"] != nil)
        // avatar_url can be nil but the key must exist (or be omitted — both are fine for optional)
        #expect(json["created_at"] != nil)
        // Verify NO camelCase leakage
        #expect(json["avatarURL"] == nil)
        #expect(json["createdAt"] == nil)
    }

    @Test("User model round-trips through JSON encoding")
    func userRoundTripsJSON() throws {
        // WHY: If encoding/decoding is broken, auth responses from Supabase
        // will fail to parse and the user will never log in.
        let original = Fake.user(
            username: "roundtrip",
            name: "Round Trip",
            email: "round@onehome.app",
            avatarURL: "https://cdn.example.com/avatar.jpg"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(User.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.username == original.username)
        #expect(decoded.name == original.name)
        #expect(decoded.email == original.email)
        #expect(decoded.avatarURL == original.avatarURL)
    }

    // MARK: - Post

    @Test("Post coding keys match schema columns")
    func postCodingKeysMatchSchema() throws {
        // Schema: id, home_id, user_id, category, text, image_url,
        //         is_draft, kudos_count, created_at
        let post = Fake.post()
        let json = try jsonKeys(from: post)

        #expect(json["id"] != nil)
        #expect(json["home_id"] != nil)
        #expect(json["user_id"] != nil)
        #expect(json["category"] != nil)
        #expect(json["text"] != nil)
        #expect(json["is_draft"] != nil)
        #expect(json["kudos_count"] != nil)
        #expect(json["created_at"] != nil)
        // Verify NO camelCase leakage
        #expect(json["homeID"] == nil)
        #expect(json["userID"] == nil)
        #expect(json["isDraft"] == nil)
        #expect(json["kudosCount"] == nil)
        #expect(json["createdAt"] == nil)
        #expect(json["imageURL"] == nil)
    }

    @Test("Post with all fields round-trips through JSON")
    func postRoundTripsJSON() throws {
        // WHY: Posts drive the entire feed. If any field breaks round-trip,
        // the feed will show corrupted or missing data.
        let author = Fake.user()
        let original = Fake.post(
            category: .purchase,
            text: "Bought olive oil $12.50",
            imageURL: "https://cdn.example.com/img.jpg",
            isDraft: false,
            kudosCount: 7,
            author: author
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Post.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.homeID == original.homeID)
        #expect(decoded.userID == original.userID)
        #expect(decoded.category == original.category)
        #expect(decoded.text == original.text)
        #expect(decoded.imageURL == original.imageURL)
        #expect(decoded.isDraft == original.isDraft)
        #expect(decoded.kudosCount == original.kudosCount)
    }

    @Test("Draft post has is_draft=true in JSON")
    func draftPostHasIsDraftTrue() throws {
        // WHY: Drafts are saved to the DB with is_draft=true. If the encoding
        // is wrong, drafts will be published immediately — a data integrity bug.
        let draft = Fake.draftPost()
        let json = try jsonKeys(from: draft)

        let isDraft = json["is_draft"] as? Bool
        #expect(isDraft == true)
    }

    @Test("Published post has is_draft=false in JSON")
    func publishedPostHasIsDraftFalse() throws {
        // WHY: Published posts must have is_draft=false in the DB. A wrong
        // value here would hide the post from the feed query.
        let published = Fake.chorePost()
        let json = try jsonKeys(from: published)

        let isDraft = json["is_draft"] as? Bool
        #expect(isDraft == false)
    }

    // MARK: - Home

    @Test("Home coding keys match schema columns")
    func homeCodingKeysMatchSchema() throws {
        // Schema: id, name, owner_id, invite_code, created_at
        let home = Fake.home()
        let json = try jsonKeys(from: home)

        #expect(json["id"] != nil)
        #expect(json["name"] != nil)
        #expect(json["owner_id"] != nil)
        #expect(json["invite_code"] != nil)
        #expect(json["created_at"] != nil)
        // Verify NO camelCase leakage
        #expect(json["ownerID"] == nil)
        #expect(json["inviteCode"] == nil)
        #expect(json["createdAt"] == nil)
    }

    @Test("Home with members round-trips through JSON")
    func homeWithMembersRoundTrips() throws {
        // WHY: Home members are fetched via a join query. If the members
        // field name doesn't match Supabase's response key, members will be nil.
        let members = [Fake.user(), Fake.user2(), Fake.user3()]
        let original = Fake.home(members: members)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Home.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.ownerID == original.ownerID)
        #expect(decoded.inviteCode == original.inviteCode)
        #expect(decoded.members?.count == members.count)
    }

    // MARK: - StickyNote

    @Test("StickyNote coding keys match schema columns")
    func stickyNoteCodingKeysMatchSchema() throws {
        // Schema: id, home_id, user_id, text, created_at, expires_at
        let note = Fake.stickyNote()
        let json = try jsonKeys(from: note)

        #expect(json["id"] != nil)
        #expect(json["home_id"] != nil)
        #expect(json["user_id"] != nil)
        #expect(json["text"] != nil)
        #expect(json["created_at"] != nil)
        #expect(json["expires_at"] != nil)
        // Verify NO camelCase leakage
        #expect(json["homeID"] == nil)
        #expect(json["userID"] == nil)
        #expect(json["createdAt"] == nil)
        #expect(json["expiresAt"] == nil)
    }

    @Test("StickyNote round-trips through JSON encoding")
    func stickyNoteRoundTripsJSON() throws {
        let original = Fake.stickyNote(
            text: "WiFi password is meow123 🐱",
            expiresAt: Date().addingTimeInterval(24 * 3600)
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(StickyNote.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.homeID == original.homeID)
        #expect(decoded.userID == original.userID)
        #expect(decoded.text == original.text)
    }

    // MARK: - UserMetrics

    @Test("UserMetrics coding keys match schema columns")
    func userMetricsCodingKeysMatchSchema() throws {
        // Schema: id, user_id, home_id, chores_done, total_spent, last_post_at
        let m = Fake.metrics()
        let json = try jsonKeys(from: m)

        #expect(json["id"] != nil)
        #expect(json["user_id"] != nil)
        #expect(json["home_id"] != nil)
        #expect(json["chores_done"] != nil)
        #expect(json["total_spent"] != nil)
        // last_post_at is optional but should encode when present
        #expect(json["last_post_at"] != nil)
        // Verify NO camelCase leakage
        #expect(json["userID"] == nil)
        #expect(json["homeID"] == nil)
        #expect(json["choresDone"] == nil)
        #expect(json["totalSpent"] == nil)
        #expect(json["lastPostAt"] == nil)
    }

    @Test("UserMetrics round-trips through JSON encoding")
    func userMetricsRoundTripsJSON() throws {
        let original = Fake.metrics(choresDone: 12, totalSpent: 134.75)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(UserMetrics.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.userID == original.userID)
        #expect(decoded.homeID == original.homeID)
        #expect(decoded.choresDone == original.choresDone)
        #expect(decoded.totalSpent == original.totalSpent)
    }

    @Test("UserMetrics with nil lastPostAt encodes correctly")
    func userMetricsNilLastPostAtEncodes() throws {
        // WHY: A user who has never posted has lastPostAt = nil. Encoding
        // must not crash and the key must be absent or null in JSON.
        let m = Fake.metrics(lastPostAt: nil)
        let data = try encoder.encode(m)
        // Should encode without throwing
        #expect(data.count > 0)

        // Decoding back should also work
        let decoded = try decoder.decode(UserMetrics.self, from: data)
        #expect(decoded.lastPostAt == nil)
    }

    // MARK: - PostCategory

    @Test("PostCategory raw values match schema check constraint")
    func postCategoryValuesMatchSchema() {
        // Schema: check (category in ('chore', 'purchase', 'general'))
        // If these don't match, every post insert will fail the DB check constraint.
        #expect(PostCategory.chore.rawValue == "chore")
        #expect(PostCategory.purchase.rawValue == "purchase")
        #expect(PostCategory.general.rawValue == "general")
    }

    @Test("PostCategory encodes to correct string in JSON")
    func postCategoryEncodesCorrectly() throws {
        // WHY: PostCategory is a String enum but we want to confirm the actual
        // JSON value Supabase receives — not just the rawValue.
        let post = Fake.post(category: .chore)
        let json = try jsonKeys(from: post)
        let category = json["category"] as? String
        #expect(category == "chore")
    }

    @Test("All PostCategory cases are covered by schema constraint")
    func allPostCategoriesCoveredBySchema() {
        // WHY: If someone adds a new case to PostCategory without updating the
        // DB check constraint, every post with that category will fail to save.
        let schemaValues: Set<String> = ["chore", "purchase", "general"]
        let swiftValues = Set(PostCategory.allCases.map { $0.rawValue })
        #expect(swiftValues == schemaValues)
    }
}
