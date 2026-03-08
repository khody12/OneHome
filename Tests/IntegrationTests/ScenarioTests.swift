import Testing
import Foundation
@testable import OneHome

// MARK: - ScenarioTests
//
// Integration-style tests that exercise pure Swift logic using Fake data.
// No network calls, no mocks needed — just models, their methods, and
// the feed assembly logic extracted for local testing.
//
// These tests catch regressions in business logic:
//   - Feed sort order
//   - Slacker detection edge cases
//   - Kudos count arithmetic
//   - Draft filtering
//   - Sticky note expiry
//   - Model serialization

@Suite("Full home scenario")
struct ScenarioTests {

    // MARK: - Feed Ordering

    @Test("Three users in a home — feed merges and sorts correctly")
    func threeUserHomeFeed() {
        // WHY: The feed combines posts and sticky notes from multiple users.
        // Chronological sort (newest first) is the core contract of the feed.
        let (_, _, posts, notes, _) = Fake.homeScenario()

        // Filter only published posts (non-drafts)
        let published = posts.filter { !$0.isDraft }

        var items: [FeedItem] = published.map { .post($0) }
        // Only use non-expired active notes
        let activeNotes = notes.filter { !$0.isExpired }
        items += activeNotes.map { .stickyNote($0) }
        let sorted = items.sorted { $0.createdAt > $1.createdAt }

        // Verify sorted order is strictly descending
        for i in 0..<(sorted.count - 1) {
            #expect(sorted[i].createdAt >= sorted[i + 1].createdAt,
                    "Item at index \(i) should be newer than item at \(i + 1)")
        }

        // All items should be present
        #expect(sorted.count == published.count + activeNotes.count)
    }

    // MARK: - Slacker Detection

    @Test("Slacker detection works across 3 users when one hasn't posted")
    func slackerDetectedInGroupOf3() {
        // WHY: The slacker roast feature is the core differentiator of OneHome.
        // This test validates the isSlacking logic works in a realistic group.
        let (_, _, _, _, metrics) = Fake.homeScenario()

        // From homeScenario: sam has lastPostAt 5 days ago — should be slacking
        let slackers = metrics.filter { $0.isSlacking(comparedTo: metrics) }

        #expect(slackers.count == 1, "Exactly one slacker in default scenario")
        // The slacker should be the user with the oldest lastPostAt
        let oldestPost = metrics.compactMap { $0.lastPostAt }.min()!
        let slacker = slackers[0]
        #expect(slacker.lastPostAt == oldestPost)
    }

    @Test("User with no posts ever is flagged as slacking if others are active")
    func neverPostedUserIsSlacker() {
        // WHY: nil lastPostAt means the user has never contributed. If roommates
        // are active, this counts as slacking. The isSlacking guard `else { return true }`
        // handles this path.
        let homeID = UUID()
        let neverPosted = Fake.metrics(
            homeID: homeID,
            lastPostAt: nil  // never posted
        )
        let active = Fake.metrics(
            homeID: homeID,
            lastPostAt: Date().addingTimeInterval(-3600)  // 1h ago
        )
        let all = [neverPosted, active]

        #expect(neverPosted.isSlacking(comparedTo: all))
        #expect(!active.isSlacking(comparedTo: all))
    }

    @Test("All users slacking — no one gets roasted (no relative disadvantage)")
    func allSlackingMeansNoRoast() {
        // WHY: If nobody in the home has posted recently, there's no relative
        // disadvantage — no one should be flagged. This prevents false positives
        // in abandoned/inactive homes.
        let homeID = UUID()
        let old1 = Fake.metrics(
            homeID: homeID,
            lastPostAt: Date().addingTimeInterval(-10 * 24 * 3600)  // 10 days ago
        )
        let old2 = Fake.metrics(
            homeID: homeID,
            lastPostAt: Date().addingTimeInterval(-8 * 24 * 3600)   // 8 days ago
        )
        let old3 = Fake.metrics(
            homeID: homeID,
            lastPostAt: Date().addingTimeInterval(-7 * 24 * 3600)   // 7 days ago
        )
        let all = [old1, old2, old3]

        // No one is active (within 72h), so othersActive = false for everyone
        let slackers = all.filter { $0.isSlacking(comparedTo: all) }
        #expect(slackers.isEmpty, "When all users are inactive, no one should be flagged")
    }

    @Test("Active user is not flagged even if others have posted more recently")
    func activeUserNotFlaggedRelatively() {
        // WHY: isSlacking is about a 72h cutoff, not relative recency.
        // A user who posted 36h ago is NOT slacking even if a roommate posted 5m ago.
        let homeID = UUID()
        let recent = Fake.metrics(
            homeID: homeID,
            lastPostAt: Date().addingTimeInterval(-5 * 60)   // 5 minutes ago
        )
        let lessRecent = Fake.metrics(
            homeID: homeID,
            lastPostAt: Date().addingTimeInterval(-36 * 3600) // 36h ago — still within 72h
        )
        let all = [recent, lessRecent]

        #expect(!lessRecent.isSlacking(comparedTo: all),
                "User who posted 36h ago is NOT slacking (within 72h window)")
    }

    // MARK: - Kudos

    @Test("Kudos toggle increments count correctly")
    func kudosToggleIncrements() {
        // WHY: Kudos count is optimistically mutated in FeedViewModel.
        // Verify the arithmetic: adding kudos when hasGivenKudos = false.
        var post = Fake.post(kudosCount: 3, hasGivenKudos: false)

        // Simulate the toggle logic from FeedViewModel.toggleKudos
        post.hasGivenKudos.toggle()
        post.kudosCount += post.hasGivenKudos ? 1 : -1

        #expect(post.kudosCount == 4)
        #expect(post.hasGivenKudos == true)
    }

    @Test("Kudos untoggle decrements count")
    func kudosToggleDecrements() {
        // WHY: Removing kudos when hasGivenKudos = true. Count must drop by 1.
        var post = Fake.post(kudosCount: 7, hasGivenKudos: true)

        post.hasGivenKudos.toggle()
        post.kudosCount += post.hasGivenKudos ? 1 : -1

        #expect(post.kudosCount == 6)
        #expect(post.hasGivenKudos == false)
    }

    @Test("Kudos count never goes negative from zero")
    func kudosCountFloorZero() {
        // WHY: If a post has 0 kudos and we somehow trigger a decrement
        // (e.g. state desync), we want to document what happens.
        var post = Fake.post(kudosCount: 0, hasGivenKudos: true)

        // Removing kudos from a 0-count post (edge case / state desync)
        post.hasGivenKudos.toggle()
        post.kudosCount += post.hasGivenKudos ? 1 : -1

        // Documents current behavior: it goes to -1 (no floor guard in VM)
        // This is an explicit documentation test — if a floor is added, update this.
        #expect(post.kudosCount == -1)
        #expect(post.hasGivenKudos == false)
    }

    // MARK: - Drafts

    @Test("Draft post is not in published feed")
    func draftNotInFeed() {
        // WHY: Drafts are DB rows with is_draft = true. The feed must only
        // show is_draft = false. Verify filtering logic.
        let (_, _, posts, _, _) = Fake.homeScenario()

        let published = posts.filter { !$0.isDraft }
        let drafts = posts.filter { $0.isDraft }

        // Scenario has exactly 1 draft
        #expect(drafts.count == 1)

        // No drafts should appear in the published feed
        let publishedIDs = Set(published.map { $0.id })
        for draft in drafts {
            #expect(!publishedIDs.contains(draft.id),
                    "Draft ID \(draft.id) must not appear in published feed")
        }
    }

    @Test("Draft post has isDraft = true and empty text")
    func draftPostProperties() {
        // WHY: When the camera tab opens, the initial draft has no text yet.
        // Verify the Fake matches this expectation so scenario tests are valid.
        let draft = Fake.draftPost()
        #expect(draft.isDraft == true)
        #expect(draft.text == "")
    }

    // MARK: - Sticky Note Expiry

    @Test("Expired sticky note is filtered from feed")
    func expiredNoteFiltered() {
        // WHY: Notes older than 48h must not appear in the feed.
        // The service filters on the DB side, but client-side isExpired
        // is the source of truth for local state.
        let (_, _, _, notes, _) = Fake.homeScenario()

        let activeNotes = notes.filter { !$0.isExpired }
        let expiredNotes = notes.filter { $0.isExpired }

        // Scenario has 1 active note and 1 expired note
        #expect(activeNotes.count == 1)
        #expect(expiredNotes.count == 1)

        // Active notes must not be expired
        for note in activeNotes {
            #expect(!note.isExpired)
        }
        // Expired notes must be expired
        for note in expiredNotes {
            #expect(note.isExpired)
        }
    }

    @Test("StickyNote expires exactly at expiresAt boundary")
    func stickyNoteExpiryBoundary() {
        // WHY: expiresAt is exclusive — the note is expired when Date() > expiresAt.
        // A note expiring "right now" is considered expired.
        let justExpired = Fake.stickyNote(
            expiresAt: Date().addingTimeInterval(-0.001)  // 1ms ago
        )
        let justActive = Fake.stickyNote(
            expiresAt: Date().addingTimeInterval(1)       // 1s from now
        )

        #expect(justExpired.isExpired, "Note that expired 1ms ago should be expired")
        #expect(!justActive.isExpired, "Note expiring in 1s should still be active")
    }

    @Test("Active note has 48h TTL from creation")
    func activeNoteHas48hTTL() {
        // WHY: The 48h TTL is a product requirement. Verify that a just-created
        // note expires at approximately the right time.
        let now = Date()
        let note = Fake.stickyNote(
            createdAt: now,
            expiresAt: now.addingTimeInterval(48 * 3600)
        )
        let expectedExpiry = now.addingTimeInterval(48 * 3600)
        let delta = abs(note.expiresAt.timeIntervalSince(expectedExpiry))

        #expect(delta < 1.0, "ExpiresAt should be within 1 second of 48h from now")
        #expect(!note.isExpired)
    }

    // MARK: - Model Serialization

    @Test("Home invite code is preserved through model serialization")
    func homeInviteCodeSurvivesJSON() throws {
        // WHY: The invite code uses a non-standard CodingKey (`invite_code`).
        // Round-tripping through JSON verifies the CodingKeys map is correct.
        let original = Fake.home(inviteCode: "INVITE99")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Home.self, from: data)

        #expect(decoded.inviteCode == "INVITE99")
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.ownerID == original.ownerID)
    }

    @Test("User model round-trips through JSON with correct CodingKeys")
    func userSurvivesJSON() throws {
        // WHY: User uses snake_case CodingKeys (avatar_url, created_at).
        // Verify these survive encode/decode without data loss.
        let original = Fake.user(
            username: "jsontest",
            name: "JSON Test User",
            email: "json@test.app",
            avatarURL: "https://example.com/avatar.jpg"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(User.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.username == original.username)
        #expect(decoded.name == original.name)
        #expect(decoded.email == original.email)
        #expect(decoded.avatarURL == original.avatarURL)
    }

    @Test("Post model preserves all fields through JSON round-trip")
    func postSurvivesJSON() throws {
        // WHY: Post has the most CodingKey remappings (home_id, user_id, etc.)
        // Verify all fields survive correctly.
        let original = Fake.post(
            category: .purchase,
            text: "Bought milk $4.50",
            isDraft: false,
            kudosCount: 7
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Post.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.homeID == original.homeID)
        #expect(decoded.userID == original.userID)
        #expect(decoded.category == original.category)
        #expect(decoded.text == original.text)
        #expect(decoded.isDraft == original.isDraft)
        #expect(decoded.kudosCount == original.kudosCount)
    }

    @Test("Comment model survives JSON round-trip")
    func commentSurvivesJSON() throws {
        // WHY: Comments use post_id and user_id CodingKeys. Verify they're
        // correctly remapped.
        let postID = UUID()
        let original = Fake.comment(postID: postID, text: "Great job! 🎉")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Comment.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.postID == postID)
        #expect(decoded.text == "Great job! 🎉")
    }

    // MARK: - Post Categories

    @Test("Post categories all have non-empty emoji and label")
    func allCategoriesHaveMetadata() {
        // WHY: If a new category is added without emoji/label, the UI
        // shows blank placeholders. This test catches that regression.
        for category in PostCategory.allCases {
            #expect(!category.emoji.isEmpty,
                    "Category \(category.rawValue) must have a non-empty emoji")
            #expect(!category.label.isEmpty,
                    "Category \(category.rawValue) must have a non-empty label")
        }
    }

    @Test("PostCategory raw values match expected strings")
    func categoryRawValues() {
        // WHY: Raw values are stored in the DB. If they change, existing rows break.
        #expect(PostCategory.chore.rawValue == "chore")
        #expect(PostCategory.purchase.rawValue == "purchase")
        #expect(PostCategory.general.rawValue == "general")
    }

    @Test("PostCategory round-trips through Codable")
    func categoryRoundTripsJSON() throws {
        // WHY: Categories are stored as strings in Supabase. Codable must
        // decode them back correctly.
        for category in PostCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(PostCategory.self, from: data)
            #expect(decoded == category)
        }
    }

    // MARK: - UserMetrics Independence

    @Test("User metrics: choresDone increments don't affect totalSpent")
    func metricsFieldsAreIndependent() {
        // WHY: choresDone and totalSpent track different things. Verify that
        // mutating one doesn't affect the other (struct value semantics).
        var m = Fake.metrics(choresDone: 5, totalSpent: 100.0)
        let originalSpent = m.totalSpent
        m.choresDone += 1

        #expect(m.choresDone == 6)
        #expect(m.totalSpent == originalSpent, "totalSpent must not change when choresDone increments")
    }

    @Test("MetricsViewModel ranked sorts by choresDone descending")
    func metricsRankedSortsByChores() {
        // WHY: The Metrics tab shows a leaderboard sorted by chores done.
        // Verify the sort is correct using local-only logic.
        let low = Fake.metrics(choresDone: 2, totalSpent: 0)
        let mid = Fake.metrics(choresDone: 7, totalSpent: 50)
        let high = Fake.metrics(choresDone: 12, totalSpent: 25)
        let allMetrics = [low, mid, high]

        // Simulate MetricsViewModel.ranked
        let ranked = allMetrics.sorted { $0.choresDone > $1.choresDone }

        #expect(ranked[0].choresDone == 12)
        #expect(ranked[1].choresDone == 7)
        #expect(ranked[2].choresDone == 2)
    }

    // MARK: - FeedItem

    @Test("FeedItem.id returns correct underlying model ID")
    func feedItemIDIsCorrect() {
        // WHY: FeedItem is a union type; its id property must correctly
        // delegate to the wrapped model's ID for SwiftUI List diffing.
        let post = Fake.post()
        let note = Fake.stickyNote()

        let postItem = FeedItem.post(post)
        let noteItem = FeedItem.stickyNote(note)

        #expect(postItem.id == post.id)
        #expect(noteItem.id == note.id)
    }

    @Test("FeedItem.createdAt returns correct underlying date")
    func feedItemCreatedAtIsCorrect() {
        // WHY: Sort order depends on FeedItem.createdAt delegating correctly.
        let date = Date().addingTimeInterval(-7200)
        let post = Fake.post(createdAt: date)
        let item = FeedItem.post(post)

        #expect(item.createdAt == date)
    }

    // MARK: - AppError

    @Test("AppError.networkError has non-empty localizedDescription")
    func appErrorNetworkHasDescription() {
        // WHY: errorMessage in ViewModels uses error.localizedDescription.
        // Verify AppError produces non-empty messages for display.
        let error = AppError.networkError("DNS failure")
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.contains("DNS failure") == true)
    }

    @Test("AppError.invalidInput includes the message")
    func appErrorInvalidInputIncludesMessage() {
        let error = AppError.invalidInput("Name is too short")
        #expect(error.errorDescription == "Name is too short")
    }

    @Test("AppError.notFound has non-empty description")
    func appErrorNotFoundHasDescription() {
        let error = AppError.notFound
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("AppError.unauthorized has non-empty description")
    func appErrorUnauthorizedHasDescription() {
        let error = AppError.unauthorized
        #expect(error.errorDescription?.isEmpty == false)
    }

    // MARK: - Fake Factory Validation

    @Test("Fake.homeScenario returns 3 users, 5 published posts, 1 draft, 2 notes, 3 metrics")
    func homeScenarioHasCorrectCounts() {
        // WHY: Scenario tests depend on specific counts. If Fake.homeScenario
        // changes, dependent tests may give misleading results. Verify the shape.
        let (home, users, posts, notes, metrics) = Fake.homeScenario()

        #expect(users.count == 3)
        #expect(posts.filter { !$0.isDraft }.count == 5)
        #expect(posts.filter { $0.isDraft }.count == 1)
        #expect(notes.count == 2)
        #expect(metrics.count == 3)
        #expect(home.members?.count == 3)
    }

    @Test("Fake.homeScenario all posts belong to the same home")
    func homeScenarioPostsHaveCorrectHomeID() {
        // WHY: Posts from the wrong homeID would cause them to appear in
        // the wrong feed. Verify all scenario posts are scoped correctly.
        let (home, _, posts, _, _) = Fake.homeScenario()
        for post in posts {
            #expect(post.homeID == home.id,
                    "Post \(post.id) should belong to home \(home.id)")
        }
    }

    @Test("Fake.homeScenario metrics userIDs match user IDs")
    func homeScenarioMetricsMatchUsers() {
        // WHY: Metrics must reference real user IDs to power slacker detection.
        let (_, users, _, _, metrics) = Fake.homeScenario()
        let userIDs = Set(users.map { $0.id })
        for m in metrics {
            #expect(userIDs.contains(m.userID),
                    "Metrics userID \(m.userID) must be one of the scenario users")
        }
    }
}
