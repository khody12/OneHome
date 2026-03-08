import Foundation
@testable import OneHome

// MARK: - Fake Data Factory
//
// Central factory for all test fixtures. Every model has a static `make()` function
// with sensible defaults and fully overridable parameters. Use Fake.homeScenario()
// to get a complete multi-user setup ready for scenario tests.

enum Fake {

    // MARK: - Users

    static func user(
        id: UUID = UUID(),
        username: String = "testuser",
        name: String = "Test User",
        email: String = "test@onehome.app",
        avatarURL: String? = nil,
        createdAt: Date = Date()
    ) -> User {
        User(
            id: id,
            username: username,
            name: name,
            email: email,
            avatarURL: avatarURL,
            createdAt: createdAt
        )
    }

    /// A second distinct user for multi-user scenarios
    static func user2() -> User {
        user(
            username: "jordansmith",
            name: "Jordan Smith",
            email: "jordan@onehome.app"
        )
    }

    /// A third distinct user — the slacker in default scenarios
    static func user3() -> User {
        user(
            username: "alexdoe",
            name: "Alex Doe",
            email: "alex@onehome.app"
        )
    }

    // MARK: - Homes

    static func home(
        id: UUID = UUID(),
        name: String = "The Test Pad",
        ownerID: UUID = UUID(),
        inviteCode: String = "TESTCODE",
        createdAt: Date = Date(),
        members: [User]? = nil
    ) -> Home {
        Home(
            id: id,
            name: name,
            ownerID: ownerID,
            createdAt: createdAt,
            inviteCode: inviteCode,
            members: members
        )
    }

    // MARK: - Posts

    static func post(
        id: UUID = UUID(),
        homeID: UUID = UUID(),
        userID: UUID = UUID(),
        category: PostCategory = .chore,
        text: String = "Did the dishes 🍽️",
        imageURL: String? = nil,
        isDraft: Bool = false,
        createdAt: Date = Date(),
        kudosCount: Int = 0,
        comments: [Comment]? = nil,
        author: User? = nil,
        hasGivenKudos: Bool = false
    ) -> Post {
        var p = Post(
            id: id,
            homeID: homeID,
            userID: userID,
            category: category,
            text: text,
            imageURL: imageURL,
            isDraft: isDraft,
            createdAt: createdAt,
            kudosCount: kudosCount,
            comments: comments,
            author: author
        )
        p.hasGivenKudos = hasGivenKudos
        return p
    }

    /// A published chore post with a specific author
    static func chorePost(author: User? = nil) -> Post {
        let authorUser = author ?? user()
        return post(
            userID: authorUser.id,
            category: .chore,
            text: "Cleaned the bathroom 🧹",
            isDraft: false,
            author: authorUser
        )
    }

    /// A published purchase post with a realistic amount in the text
    static func purchasePost(amount: String = "$23 on dish soap", author: User? = nil) -> Post {
        let authorUser = author ?? user()
        return post(
            userID: authorUser.id,
            category: .purchase,
            text: "Bought \(amount) 🛒",
            isDraft: false,
            author: authorUser
        )
    }

    /// A draft post that should never appear in the published feed
    static func draftPost(homeID: UUID = UUID(), userID: UUID = UUID()) -> Post {
        post(
            homeID: homeID,
            userID: userID,
            category: .chore,
            text: "",
            isDraft: true
        )
    }

    /// A general announcement post
    static func generalPost(text: String = "Party this Friday! 📣", author: User? = nil) -> Post {
        let authorUser = author ?? user()
        return post(
            userID: authorUser.id,
            category: .general,
            text: text,
            isDraft: false,
            author: authorUser
        )
    }

    // MARK: - StickyNotes

    static func stickyNote(
        id: UUID = UUID(),
        homeID: UUID = UUID(),
        userID: UUID = UUID(),
        text: String = "Lock the door! 🔒",
        createdAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(48 * 3600),
        author: User? = nil
    ) -> StickyNote {
        StickyNote(
            id: id,
            homeID: homeID,
            userID: userID,
            text: text,
            createdAt: createdAt,
            expiresAt: expiresAt,
            author: author
        )
    }

    /// A sticky note that has already passed its expiry time
    static func expiredStickyNote(homeID: UUID = UUID()) -> StickyNote {
        stickyNote(
            homeID: homeID,
            text: "This note is stale ☠️",
            createdAt: Date().addingTimeInterval(-50 * 3600),
            expiresAt: Date().addingTimeInterval(-2 * 3600)  // expired 2 hours ago
        )
    }

    /// A sticky note expiring exactly at the boundary (1 second from now — still active)
    static func almostExpiredStickyNote(homeID: UUID = UUID()) -> StickyNote {
        stickyNote(
            homeID: homeID,
            text: "Almost gone ⏰",
            expiresAt: Date().addingTimeInterval(1)
        )
    }

    // MARK: - Comments

    static func comment(
        id: UUID = UUID(),
        postID: UUID = UUID(),
        userID: UUID = UUID(),
        text: String = "Nice work! 🙌",
        createdAt: Date = Date(),
        author: User? = nil
    ) -> Comment {
        Comment(
            id: id,
            postID: postID,
            userID: userID,
            text: text,
            createdAt: createdAt,
            author: author
        )
    }

    // MARK: - UserMetrics

    static func metrics(
        id: UUID = UUID(),
        userID: UUID = UUID(),
        homeID: UUID = UUID(),
        choresDone: Int = 5,
        totalSpent: Double = 42.0,
        lastPostAt: Date? = Date().addingTimeInterval(-3600),  // 1 hour ago — active
        user: User? = nil
    ) -> UserMetrics {
        UserMetrics(
            id: id,
            userID: userID,
            homeID: homeID,
            choresDone: choresDone,
            totalSpent: totalSpent,
            lastPostAt: lastPostAt,
            user: user
        )
    }

    /// Metrics for a user who is clearly slacking relative to others
    /// Pass in the other metrics to confirm the relative comparison works
    static func slackingMetrics(comparedTo others: [UserMetrics]) -> UserMetrics {
        // Last post was 5 days ago — well beyond the 72h cutoff
        metrics(
            choresDone: 0,
            totalSpent: 0.0,
            lastPostAt: Date().addingTimeInterval(-5 * 24 * 3600)
        )
    }

    // MARK: - PendingInvites

    static func pendingInvite(
        id: UUID = UUID(),
        homeID: UUID = UUID(),
        inviteeID: UUID = UUID(),
        inviterID: UUID = UUID(),
        status: String = "pending",
        createdAt: Date = Date(),
        home: Home? = nil,
        inviter: User? = nil
    ) -> PendingInvite {
        PendingInvite(
            id: id,
            homeID: homeID,
            inviteeID: inviteeID,
            inviterID: inviterID,
            status: status,
            createdAt: createdAt,
            home: home,
            inviter: inviter
        )
    }

    /// A pending invite that has been accepted
    static func acceptedInvite(
        homeID: UUID = UUID(),
        inviteeID: UUID = UUID(),
        inviterID: UUID = UUID()
    ) -> PendingInvite {
        pendingInvite(
            homeID: homeID,
            inviteeID: inviteeID,
            inviterID: inviterID,
            status: "accepted"
        )
    }

    /// A pending invite that has been declined
    static func declinedInvite(
        homeID: UUID = UUID(),
        inviteeID: UUID = UUID(),
        inviterID: UUID = UUID()
    ) -> PendingInvite {
        pendingInvite(
            homeID: homeID,
            inviteeID: inviteeID,
            inviterID: inviterID,
            status: "declined"
        )
    }

    /// A pending invite with realistic home and inviter populated
    static func pendingInviteWithDetails(invitee: User? = nil) -> PendingInvite {
        let inviter = user2()
        let theHome = home(name: "The Chateau 🏰", ownerID: inviter.id)
        let inviteeID = invitee?.id ?? UUID()
        return pendingInvite(
            homeID: theHome.id,
            inviteeID: inviteeID,
            inviterID: inviter.id,
            status: "pending",
            home: theHome,
            inviter: inviter
        )
    }

    // MARK: - Full Scenarios

    /// Returns a realistic 3-user home with different posting histories so
    /// slacker tests work without any additional setup.
    ///
    /// - user1 (alex): posted 1 hour ago — active
    /// - user2 (jordan): posted 2 days ago — active (within 72h)
    /// - user3 (sam): posted 5 days ago — SLACKING
    ///
    /// Posts: 5 published posts, 1 draft, spread across categories
    /// Notes: 1 active sticky note, 1 expired sticky note
    /// Metrics: per-user metrics reflecting the above histories
    static func homeScenario() -> (
        home: Home,
        users: [User],
        posts: [Post],
        notes: [StickyNote],
        metrics: [UserMetrics]
    ) {
        let homeID = UUID()

        let alex = user(username: "alexr", name: "Alex Reyes", email: "alex@onehome.app")
        let jordan = user(username: "jordanb", name: "Jordan Bell", email: "jordan@onehome.app")
        let sam = user(username: "samw", name: "Sam Wallace", email: "sam@onehome.app")
        let users = [alex, jordan, sam]

        let home = home(
            id: homeID,
            name: "Casa de Test",
            ownerID: alex.id,
            inviteCode: "CASATEST",
            members: users
        )

        let now = Date()

        // Published posts — varying ages so sort order is deterministic
        let post1 = post(
            homeID: homeID, userID: alex.id, category: .chore,
            text: "Vacuumed the living room 🧹",
            isDraft: false,
            createdAt: now.addingTimeInterval(-1 * 3600),  // 1h ago
            kudosCount: 3, author: alex
        )
        let post2 = post(
            homeID: homeID, userID: jordan.id, category: .purchase,
            text: "Bought paper towels $8.50 🛒",
            isDraft: false,
            createdAt: now.addingTimeInterval(-6 * 3600),  // 6h ago
            kudosCount: 1, author: jordan
        )
        let post3 = post(
            homeID: homeID, userID: sam.id, category: .general,
            text: "Plumber coming tomorrow 📣",
            isDraft: false,
            createdAt: now.addingTimeInterval(-5 * 24 * 3600),  // 5 days ago
            kudosCount: 0, author: sam
        )
        let post4 = post(
            homeID: homeID, userID: alex.id, category: .purchase,
            text: "Restocked cleaning supplies $32 🛒",
            isDraft: false,
            createdAt: now.addingTimeInterval(-2 * 24 * 3600),  // 2 days ago
            kudosCount: 2, author: alex
        )
        let post5 = post(
            homeID: homeID, userID: jordan.id, category: .chore,
            text: "Took out the trash 🧹",
            isDraft: false,
            createdAt: now.addingTimeInterval(-48 * 3600),  // exactly 48h ago
            kudosCount: 4, author: jordan
        )

        // Draft — should NOT appear in published feed
        let draftPost = draftPost(homeID: homeID, userID: alex.id)

        let posts = [post1, post2, post3, post4, post5, draftPost]

        // Sticky notes
        let activeNote = stickyNote(
            homeID: homeID, userID: jordan.id,
            text: "Dishwasher is broken, hand wash only 🚿",
            createdAt: now.addingTimeInterval(-3 * 3600),
            expiresAt: now.addingTimeInterval(45 * 3600),
            author: jordan
        )
        let expiredNote = expiredStickyNote(homeID: homeID)
        let notes = [activeNote, expiredNote]

        // Metrics — sam's lastPostAt is 5 days ago (slacking)
        let alexMetrics = metrics(
            userID: alex.id, homeID: homeID,
            choresDone: 8, totalSpent: 32.0,
            lastPostAt: now.addingTimeInterval(-1 * 3600),  // active
            user: alex
        )
        let jordanMetrics = metrics(
            userID: jordan.id, homeID: homeID,
            choresDone: 5, totalSpent: 8.50,
            lastPostAt: now.addingTimeInterval(-48 * 3600),  // active (within 72h)
            user: jordan
        )
        let samMetrics = metrics(
            userID: sam.id, homeID: homeID,
            choresDone: 1, totalSpent: 0.0,
            lastPostAt: now.addingTimeInterval(-5 * 24 * 3600),  // SLACKING
            user: sam
        )
        let allMetrics = [alexMetrics, jordanMetrics, samMetrics]

        return (home, users, posts, notes, allMetrics)
    }
}
