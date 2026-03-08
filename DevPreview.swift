import Foundation

// MARK: - Dev Preview Data
// Fake data used only in DEBUG builds to bypass Supabase and test the UI in simulator.
// Remove or ignore this file in production.

#if DEBUG
enum DevPreview {
    static let user = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "you",
        name: "You (Dev)",
        email: "dev@onehome.app",
        avatarURL: nil,
        createdAt: Date()
    )

    static let roommate1 = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        username: "alex",
        name: "Alex",
        email: "alex@onehome.app",
        avatarURL: nil,
        createdAt: Date()
    )

    static let roommate2 = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        username: "jordan",
        name: "Jordan",
        email: "jordan@onehome.app",
        avatarURL: nil,
        createdAt: Date()
    )

    static let home = Home(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        name: "The Dev Pad 🏚️",
        ownerID: user.id,
        createdAt: Date(),
        inviteCode: "DEVCODE",
        members: [user, roommate1, roommate2]
    )

    static let purchasePostID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
    static let paymentRequestID = UUID(uuidString: "00000000-0000-0000-0000-000000000030")!

    static let paymentRequest = PaymentRequest(
        id: paymentRequestID,
        postID: purchasePostID,
        homeID: home.id,
        requestorID: user.id,
        totalAmount: 18.50,
        note: "Groceries run 🛒",
        createdAt: Date().addingTimeInterval(-7200),
        splits: [
            PaymentSplit(id: UUID(), paymentRequestID: paymentRequestID, userID: roommate1.id, amount: 9.25, isPaid: true, createdAt: Date(), user: roommate1),
            PaymentSplit(id: UUID(), paymentRequestID: paymentRequestID, userID: roommate2.id, amount: 9.25, isPaid: false, createdAt: Date(), user: roommate2)
        ]
    )

    static let posts: [Post] = [
        Post(
            id: UUID(),
            homeID: home.id,
            userID: roommate1.id,
            category: .chore,
            text: "Did all the dishes AND wiped the counters. You're welcome 😤",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-3600),
            kudosCount: 3,
            comments: [
                Comment(id: UUID(), postID: UUID(), userID: user.id, text: "Legend 🙌", createdAt: Date().addingTimeInterval(-1800), author: user)
            ],
            author: roommate1,
            hasGivenKudos: true
        ),
        Post(
            id: purchasePostID,
            homeID: home.id,
            userID: user.id,
            category: .purchase,
            text: "Bought toilet paper, dish soap, and a new sponge. $18.50. Someone Venmo me 👀",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-7200),
            kudosCount: 2,
            comments: [],
            author: user,
            hasGivenKudos: false,
            paymentRequest: paymentRequest
        ),
        Post(
            id: UUID(),
            homeID: home.id,
            userID: roommate2.id,
            category: .general,
            text: "Heads up — I'll be having people over Friday night 🎉",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-86400),
            kudosCount: 0,
            comments: [],
            author: roommate2,
            hasGivenKudos: false
        )
    ]

    static let stickyNotes: [StickyNote] = [
        StickyNote(
            id: UUID(),
            homeID: home.id,
            userID: roommate1.id,
            text: "Lock the front door when you leave!! 🔒",
            createdAt: Date().addingTimeInterval(-1800),
            expiresAt: Date().addingTimeInterval(46 * 3600),
            author: roommate1
        )
    ]

    static let metrics: [UserMetrics] = [
        UserMetrics(id: UUID(), userID: roommate1.id, homeID: home.id, choresDone: 12, totalSpent: 45.0, lastPostAt: Date().addingTimeInterval(-3600), user: roommate1),
        UserMetrics(id: UUID(), userID: user.id, homeID: home.id, choresDone: 8, totalSpent: 18.50, lastPostAt: Date().addingTimeInterval(-7200), user: user),
        UserMetrics(id: UUID(), userID: roommate2.id, homeID: home.id, choresDone: 1, totalSpent: 0, lastPostAt: Date().addingTimeInterval(-5 * 86400), user: roommate2)
    ]

    static var feedItems: [FeedItem] {
        var items: [FeedItem] = posts.map { .post($0) }
        items += stickyNotes.map { .stickyNote($0) }
        return items.sorted { $0.createdAt > $1.createdAt }
    }
}
#endif
