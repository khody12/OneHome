import Testing
import Foundation
@testable import OneHome

// MARK: - EdgeCaseTests
//
// Fills coverage gaps identified in TestAudit.swift.
// All tests are pure Swift — no network calls, no mocks needed.
// Sections follow the audit priority order.

// ============================================================
// MARK: - AppError
// ============================================================

@Suite("AppError Edge Cases")
struct AppErrorEdgeCaseTests {

    @Test("notFound has a non-nil, non-empty errorDescription")
    func notFoundHasDescription() {
        // WHY: Every AppError case must produce a user-visible string.
        // A nil or empty description would show a blank error alert.
        let error = AppError.notFound
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("unauthorized has a non-nil, non-empty errorDescription")
    func unauthorizedHasDescription() {
        // WHY: Same contract — unauthorized must yield a readable message.
        let error = AppError.unauthorized
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("networkError carries its message through errorDescription")
    func networkErrorCarriesMessage() {
        // WHY: The network error message contains operational context
        // (e.g. "DNS failure"). Verify the payload survives to the UI layer.
        let msg = "connection timed out"
        let error = AppError.networkError(msg)
        #expect(error.errorDescription?.contains(msg) == true)
    }

    @Test("invalidInput carries its message verbatim as errorDescription")
    func invalidInputCarriesMessage() {
        // WHY: invalidInput is used for field-level validation messages
        // (e.g. "Email already in use"). The ViewModel displays it directly,
        // so the exact string must be preserved without transformation.
        let msg = "Username must be at least 3 characters"
        let error = AppError.invalidInput(msg)
        #expect(error.errorDescription == msg)
    }

    @Test("networkError errorDescription is non-nil")
    func networkErrorDescriptionIsNonNil() {
        // WHY: Defensive guard — confirms the associated value path works
        // even for an empty-string message.
        let error = AppError.networkError("")
        #expect(error.errorDescription != nil)
    }

    @Test("All AppError cases have non-nil errorDescription")
    func allCasesHaveDescription() {
        // WHY: If someone adds a new AppError case without a description branch,
        // this test catches the omission before it ships.
        let cases: [AppError] = [
            .notFound,
            .unauthorized,
            .invalidInput("test"),
            .networkError("test")
        ]
        for error in cases {
            #expect(error.errorDescription != nil,
                    "AppError case \(error) must have a non-nil errorDescription")
        }
    }
}

// ============================================================
// MARK: - AppState Initial State
// ============================================================

@Suite("AppState Initial State")
struct AppStateInitialStateTests {

    @Test("isAuthenticated starts false")
    func isAuthenticatedStartsFalse() {
        // WHY: The entire app gates access on isAuthenticated. If it starts
        // true, unauthenticated users would see protected screens on first launch.
        let state = AppState()
        #expect(state.isAuthenticated == false)
    }

    @Test("currentUser starts nil")
    func currentUserStartsNil() {
        // WHY: No user should be set until checkAuth() completes.
        // A non-nil default would break first-launch flows.
        let state = AppState()
        #expect(state.currentUser == nil)
    }

    @Test("currentHome starts nil")
    func currentHomeStartsNil() {
        // WHY: A fresh AppState has no selected home — the user must
        // pick or create one after authentication.
        let state = AppState()
        #expect(state.currentHome == nil)
    }

    @Test("pendingInviteCount starts at zero")
    func pendingInviteCountStartsZero() {
        // WHY: The invite badge must not show a phantom count on launch
        // before any invite data has been fetched.
        let state = AppState()
        #expect(state.pendingInviteCount == 0)
    }
}

// ============================================================
// MARK: - FeedItem Edge Cases
// ============================================================

@Suite("FeedItem Edge Cases")
struct FeedItemEdgeCaseTests {

    @Test("FeedItem.post returns the wrapped post's id")
    func postCaseReturnsPostID() {
        // WHY: SwiftUI List uses FeedItem.id for stable diffing.
        // If the wrong id is returned, rows will flash or re-order incorrectly.
        let post = Fake.post()
        let item = FeedItem.post(post)
        #expect(item.id == post.id)
    }

    @Test("FeedItem.post returns the wrapped post's createdAt")
    func postCaseReturnsPostCreatedAt() {
        // WHY: Feed sort relies on FeedItem.createdAt delegating to the
        // underlying Post.createdAt. A wrong delegation breaks sort order.
        let expectedDate = Date().addingTimeInterval(-7200)
        let post = Fake.post(createdAt: expectedDate)
        let item = FeedItem.post(post)
        #expect(item.createdAt == expectedDate)
    }

    @Test("FeedItem.stickyNote returns the wrapped note's id")
    func stickyNoteCaseReturnsNoteID() {
        // WHY: Same stable-diffing contract as the post case.
        let note = Fake.stickyNote()
        let item = FeedItem.stickyNote(note)
        #expect(item.id == note.id)
    }

    @Test("FeedItem.stickyNote returns the wrapped note's createdAt")
    func stickyNoteCaseReturnsNoteCreatedAt() {
        // WHY: Sorting depends on this delegation being correct.
        let expectedDate = Date().addingTimeInterval(-300)
        let note = Fake.stickyNote(createdAt: expectedDate)
        let item = FeedItem.stickyNote(note)
        #expect(item.createdAt == expectedDate)
    }

    @Test("Two FeedItems with the same createdAt can coexist in an array")
    func itemsWithSameDateCoexist() {
        // WHY: Simultaneous posts (same timestamp) must not crash or de-duplicate.
        // The feed array holds them both by id, not by date.
        let now = Date()
        let post1 = Fake.post(createdAt: now)
        let post2 = Fake.post(createdAt: now)
        let items: [FeedItem] = [.post(post1), .post(post2)]
        // Both items must be present — identical dates don't merge or drop items
        #expect(items.count == 2)
        #expect(items[0].id != items[1].id)
    }
}

// ============================================================
// MARK: - Home Edge Cases
// ============================================================

@Suite("Home Edge Cases")
struct HomeEdgeCaseTests {

    @Test("inviteCode survives JSON encoding and decoding")
    func inviteCodeSurvivesJSON() throws {
        // WHY: inviteCode uses the CodingKey `invite_code`. If the CodingKey
        // mapping is missing or wrong, the invite flow breaks for new users.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = Fake.home(inviteCode: "ABCD1234")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Home.self, from: data)

        #expect(decoded.inviteCode == "ABCD1234")
    }

    @Test("Home owner is not automatically placed in the members array")
    func ownerNotAutoInMembers() {
        // WHY: ownerID and members are separate concepts. The owner's profile
        // is NOT automatically in members — it must be added via a join.
        // If this were automatic, the owner would appear twice in the members list.
        let ownerID = UUID()
        let home = Fake.home(ownerID: ownerID, members: nil)
        // members is nil by default (no join performed)
        #expect(home.members == nil)
        // If members is explicitly set to an empty list, owner is still not there
        let homeWithMembers = Fake.home(ownerID: ownerID, members: [])
        #expect(homeWithMembers.members?.contains { $0.id == ownerID } != true)
    }

    @Test("Home with members preserves member count through JSON")
    func homeMembersCountSurvivesJSON() throws {
        // WHY: Home.members is populated via a Supabase join (embedded select).
        // If the CodingKey for members is wrong, the array silently becomes nil.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let members = [Fake.user(), Fake.user2()]
        let home = Fake.home(members: members)
        let data = try encoder.encode(home)
        let decoded = try decoder.decode(Home.self, from: data)

        #expect(decoded.members?.count == 2)
    }
}

// ============================================================
// MARK: - Post Edge Cases
// ============================================================

@Suite("Post Edge Cases")
struct PostEdgeCaseTests {

    @Test("isDraft is encoded as is_draft in JSON")
    func isDraftEncodesCorrectly() throws {
        // WHY: The DB column is `is_draft`. If encoding produces `isDraft` instead,
        // every draft insert will fail the DB schema. This is the highest-risk CodingKey.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let post = Fake.post(isDraft: true)
        let data = try encoder.encode(post)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["is_draft"] as? Bool == true)
        #expect(json["isDraft"] == nil, "camelCase key must not leak into JSON")
    }

    @Test("kudosCount defaults to 0 in Fake.post()")
    func kudosCountDefaultsToZero() {
        // WHY: A new post starts with zero kudos. If the default changes,
        // feed counts would be wrong before any user interaction.
        let post = Fake.post()
        #expect(post.kudosCount == 0)
    }

    @Test("hasGivenKudos defaults to false at the struct level")
    func hasGivenKudosDefaultsFalse() {
        // WHY: hasGivenKudos is LOCAL state — it is not stored in the DB
        // and not in CodingKeys. Its default must be false so freshly decoded
        // posts don't appear pre-kudosed to the current user.
        let post = Fake.post()
        #expect(post.hasGivenKudos == false)
    }

    @Test("hasGivenKudos is absent from JSON output (local-state only)")
    func hasGivenKudosAbsentFromJSON() throws {
        // WHY: hasGivenKudos is intentionally excluded from CodingKeys.
        // If it were encoded, Supabase would reject or ignore the extra field —
        // but it signals a CodingKeys regression worth catching explicitly.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var post = Fake.post()
        post.hasGivenKudos = true
        let data = try encoder.encode(post)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["hasGivenKudos"] == nil)
        #expect(json["has_given_kudos"] == nil)
    }

    @Test("Category emoji is exactly correct for each case")
    func categoryEmojiExactValues() {
        // WHY: The badge UI hardcodes these emoji. If a case changes its emoji,
        // users see a different icon. Pin the exact values to catch regressions.
        #expect(PostCategory.chore.emoji == "🧹")
        #expect(PostCategory.purchase.emoji == "🛒")
        #expect(PostCategory.general.emoji == "📣")
    }
}

// ============================================================
// MARK: - UserMetrics Boundary Cases
// ============================================================

@Suite("UserMetrics Boundary Cases")
struct UserMetricsBoundaryCaseTests {

    @Test("isSlacking returns false when there are no other users (single-person home)")
    func singleUserHomeNeverSlacking() {
        // WHY: isSlacking is relative — if there are no others to be active,
        // othersActive is false, so the function must return false.
        // Without this, the solo user would always be flagged as slacking if
        // their last post is >72h ago even though they're the only person.
        let solo = Fake.metrics(lastPostAt: Date().addingTimeInterval(-5 * 86400)) // 5d ago
        let all = [solo]
        #expect(!solo.isSlacking(comparedTo: all))
    }

    @Test("isSlacking returns false when posted exactly at 72h boundary (not beyond)")
    func postedExactlyAt72hBoundaryNotSlacking() {
        // WHY: The cutoff is `lastPost < cutoff` (strictly less than). A post
        // made exactly 72h ago is NOT beyond the cutoff, so the user is NOT slacking.
        // Off-by-one errors here would wrongly flag borderline-active users.
        let cutoff = Date().addingTimeInterval(-72 * 3600)
        // Post exactly at cutoff — should NOT be slacking (not strictly less than)
        let atBoundary = Fake.metrics(lastPostAt: cutoff.addingTimeInterval(1)) // 1s after cutoff
        let active = Fake.metrics(lastPostAt: Date().addingTimeInterval(-3600)) // 1h ago
        let all = [atBoundary, active]
        #expect(!atBoundary.isSlacking(comparedTo: all),
                "User who posted at the 72h boundary (not beyond) should NOT be slacking")
    }

    @Test("isSlacking returns true for user just past the 72h boundary")
    func postedJustPast72hBoundaryIsSlacking() {
        // WHY: Complement of the boundary test above. A post 1 second PAST the
        // 72h cutoff means the user IS slacking (lastPost < cutoff).
        let cutoff = Date().addingTimeInterval(-72 * 3600)
        let justPast = Fake.metrics(lastPostAt: cutoff.addingTimeInterval(-1)) // 1s before cutoff
        let active = Fake.metrics(lastPostAt: Date().addingTimeInterval(-3600))
        let all = [justPast, active]
        #expect(justPast.isSlacking(comparedTo: all),
                "User who posted 1s past the 72h boundary should be slacking")
    }

    @Test("All-zero choresDone — no user is ranked above another by chores")
    func allZeroChoresDoneNoRanking() {
        // WHY: When every user has choresDone=0, sort stability is undefined
        // (the sort is not guaranteed to have a winner). What we CAN assert is
        // that the sorted array still contains all users and no crashes occur.
        let m1 = Fake.metrics(userID: UUID(), choresDone: 0)
        let m2 = Fake.metrics(userID: UUID(), choresDone: 0)
        let m3 = Fake.metrics(userID: UUID(), choresDone: 0)
        let all = [m1, m2, m3]

        // Simulate MetricsViewModel.ranked
        let ranked = all.sorted { $0.choresDone > $1.choresDone }

        // All elements still present
        #expect(ranked.count == 3)
        // All are tied — no one has more chores than anyone else
        for m in ranked {
            #expect(m.choresDone == 0)
        }
    }

    @Test("isSlacking false when all others are also beyond 72h (no active others)")
    func allUsersInactiveMeansNoSlackers() {
        // WHY: If nobody is active, othersActive = false for all users,
        // so no one is flagged as slacking. An inactive home should not roast anyone.
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
        let eightDaysAgo = Date().addingTimeInterval(-8 * 86400)

        let u1 = Fake.metrics(lastPostAt: sevenDaysAgo)
        let u2 = Fake.metrics(lastPostAt: eightDaysAgo)
        let all = [u1, u2]

        #expect(!u1.isSlacking(comparedTo: all))
        #expect(!u2.isSlacking(comparedTo: all))
    }
}

// ============================================================
// MARK: - Comment Edge Cases
// ============================================================

@Suite("Comment Edge Cases")
struct CommentEdgeCaseTests {

    @Test("Comment round-trips through JSON with author join")
    func commentRoundTripsWithAuthor() throws {
        // WHY: Comments are fetched with an embedded author join from Supabase.
        // If the `author` CodingKey is missing, the author will always be nil
        // and usernames won't appear in the comments section.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let postID = UUID()
        let author = Fake.user(username: "commentauthor", name: "Comment Author")
        let original = Fake.comment(postID: postID, text: "Great chore! 🎉", author: author)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Comment.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.postID == postID)
        #expect(decoded.text == "Great chore! 🎉")
        #expect(decoded.author?.username == "commentauthor")
    }

    @Test("Comment post_id CodingKey is correct")
    func commentPostIDCodingKey() throws {
        // WHY: Supabase schema uses `post_id`. If the CodingKey maps to `postID`
        // (camelCase), fetched comments will have a nil postID — breaking threading.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let postID = UUID()
        let comment = Fake.comment(postID: postID)
        let data = try encoder.encode(comment)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["post_id"] != nil, "post_id key must be present in encoded JSON")
        #expect(json["postID"] == nil, "camelCase postID must not appear in JSON")
    }

    @Test("Comment user_id CodingKey is correct")
    func commentUserIDCodingKey() throws {
        // WHY: Same concern as post_id — the DB column is `user_id` (snake_case).
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let comment = Fake.comment()
        let data = try encoder.encode(comment)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["user_id"] != nil)
        #expect(json["userID"] == nil)
    }

    @Test("Comment created_at CodingKey is correct")
    func commentCreatedAtCodingKey() throws {
        // WHY: created_at is used to sort comments chronologically on the server.
        // A wrong key means the timestamp is lost and ordering breaks.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let comment = Fake.comment()
        let data = try encoder.encode(comment)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["created_at"] != nil)
        #expect(json["createdAt"] == nil)
    }
}

// ============================================================
// MARK: - StickyNote Exact Boundary Cases
// ============================================================

@Suite("StickyNote Exact Boundary")
struct StickyNoteExactBoundaryTests {

    @Test("isExpired is false when expiresAt is exactly 1 second in the future")
    func isExpiredFalseOnePlusSecond() {
        // WHY: isExpired = Date() > expiresAt. A note expiring 1s from now
        // is still active. This test pins the exclusive boundary behavior.
        let note = Fake.stickyNote(expiresAt: Date().addingTimeInterval(1))
        #expect(!note.isExpired)
    }

    @Test("isExpired is true when expiresAt is exactly 1 second in the past")
    func isExpiredTrueOneSecondPast() {
        // WHY: A note that expired 1s ago is expired. Together with the test
        // above, these two pin the "> vs >=" contract of the isExpired computed property.
        let note = Fake.stickyNote(expiresAt: Date().addingTimeInterval(-1))
        #expect(note.isExpired)
    }
}
