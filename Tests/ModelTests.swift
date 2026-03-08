import Testing
import Foundation
@testable import OneHome

// MARK: - StickyNote expiry
@Suite("StickyNote")
struct StickyNoteTests {
    @Test("Active note is not expired")
    func activeNoteNotExpired() {
        let note = StickyNote(
            id: UUID(), homeID: UUID(), userID: UUID(),
            text: "Lock the door",
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(48 * 3600),
            author: nil
        )
        #expect(!note.isExpired)
    }

    @Test("Note past expiry is expired")
    func expiredNoteIsExpired() {
        let note = StickyNote(
            id: UUID(), homeID: UUID(), userID: UUID(),
            text: "Old note",
            createdAt: Date().addingTimeInterval(-50 * 3600),
            expiresAt: Date().addingTimeInterval(-2 * 3600),
            author: nil
        )
        #expect(note.isExpired)
    }
}

// MARK: - Slacker detection
@Suite("UserMetrics")
struct UserMetricsTests {
    private func makeMetrics(userID: UUID, lastPostDaysAgo: Double?) -> UserMetrics {
        let lastPost = lastPostDaysAgo.map { Date().addingTimeInterval(-$0 * 86400) }
        return UserMetrics(id: UUID(), userID: userID, homeID: UUID(),
                           choresDone: 0, totalSpent: 0, lastPostAt: lastPost)
    }

    @Test("User who hasn't posted while others have is slacking")
    func detectsSlacker() {
        let slackerID = UUID()
        let slacker = makeMetrics(userID: slackerID, lastPostDaysAgo: 5)
        let active1 = makeMetrics(userID: UUID(), lastPostDaysAgo: 1)
        let active2 = makeMetrics(userID: UUID(), lastPostDaysAgo: 2)
        let all = [slacker, active1, active2]
        #expect(slacker.isSlacking(comparedTo: all))
    }

    @Test("User who has recently posted is not slacking")
    func activeUserNotSlacking() {
        let activeID = UUID()
        let active = makeMetrics(userID: activeID, lastPostDaysAgo: 1)
        let other = makeMetrics(userID: UUID(), lastPostDaysAgo: 0.5)
        #expect(!active.isSlacking(comparedTo: [active, other]))
    }

    @Test("User with no post ever is slacking if others are active")
    func neverPostedIsSlacking() {
        let neverPosted = makeMetrics(userID: UUID(), lastPostDaysAgo: nil)
        let active = makeMetrics(userID: UUID(), lastPostDaysAgo: 1)
        #expect(neverPosted.isSlacking(comparedTo: [neverPosted, active]))
    }
}

// MARK: - PostCategory
@Suite("PostCategory")
struct PostCategoryTests {
    @Test("All categories have emojis")
    func categoriesHaveEmojis() {
        for cat in PostCategory.allCases {
            #expect(!cat.emoji.isEmpty)
        }
    }

    @Test("Category round-trips through Codable")
    func categoryIsCodable() throws {
        let encoded = try JSONEncoder().encode(PostCategory.chore)
        let decoded = try JSONDecoder().decode(PostCategory.self, from: encoded)
        #expect(decoded == .chore)
    }
}

// MARK: - FeedItem ordering
@Suite("FeedItem")
struct FeedItemTests {
    @Test("Feed items sort newest first")
    func sortsByDate() {
        let now = Date()
        let older = FeedItem.stickyNote(StickyNote(
            id: UUID(), homeID: UUID(), userID: UUID(), text: "old",
            createdAt: now.addingTimeInterval(-3600),
            expiresAt: now.addingTimeInterval(44 * 3600), author: nil
        ))
        let newer = FeedItem.stickyNote(StickyNote(
            id: UUID(), homeID: UUID(), userID: UUID(), text: "new",
            createdAt: now,
            expiresAt: now.addingTimeInterval(48 * 3600), author: nil
        ))
        let sorted = [older, newer].sorted { $0.createdAt > $1.createdAt }
        if case .stickyNote(let s) = sorted.first {
            #expect(s.text == "new")
        } else {
            Issue.record("Expected newest note first")
        }
    }
}
