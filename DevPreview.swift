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

    static let chorePostID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    static let purchasePostID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
    static let paymentRequestID = UUID(uuidString: "00000000-0000-0000-0000-000000000030")!

    static let reactions: [Reaction] = [
        Reaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
            postID: chorePostID,
            userID: roommate2.id,
            emoji: "🐐",
            createdAt: Date().addingTimeInterval(-3000),
            user: roommate2
        ),
        Reaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
            postID: chorePostID,
            userID: user.id,
            emoji: "👍",
            createdAt: Date().addingTimeInterval(-2800),
            user: user
        ),
        Reaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000043")!,
            postID: chorePostID,
            userID: roommate1.id,
            emoji: "❤️",
            createdAt: Date().addingTimeInterval(-2600),
            user: roommate1
        )
    ]

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

    static let requestPostID = UUID(uuidString: "00000000-0000-0000-0000-000000000050")!

    static let requestPost = Post(
        id: requestPostID,
        homeID: home.id,
        userID: roommate1.id,
        category: .request,
        text: "Can someone take out the trash? It's been 3 days 🗑️",
        imageURL: nil,
        isDraft: false,
        createdAt: Date().addingTimeInterval(-10800),
        reactions: nil,
        comments: [],
        author: roommate1,
        paymentRequest: nil,
        requestedUserIDs: nil,  // open to everyone
        completionPostID: nil
    )

    static let posts: [Post] = [
        Post(
            id: chorePostID,
            homeID: home.id,
            userID: roommate1.id,
            category: .chore,
            text: "Did all the dishes AND wiped the counters. You're welcome 😤",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-3600),
            reactions: reactions,
            comments: [
                Comment(id: UUID(), postID: chorePostID, userID: user.id, text: "Legend 🙌", createdAt: Date().addingTimeInterval(-1800), author: user)
            ],
            author: roommate1,
            choreSubcategory: .dishes
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
            reactions: nil,
            comments: [],
            author: user,
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
            reactions: nil,
            comments: [],
            author: roommate2
        ),
        // Extra chore posts with subcategories for leaderboard data
        Post(
            id: UUID(),
            homeID: home.id,
            userID: user.id,
            category: .chore,
            text: "Vacuumed all the floors 🧹",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-2 * 3600),
            reactions: nil,
            comments: [],
            author: user,
            choreSubcategory: .floors
        ),
        Post(
            id: UUID(),
            homeID: home.id,
            userID: roommate1.id,
            category: .chore,
            text: "Made dinner for everyone tonight 🍳",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-5 * 3600),
            reactions: nil,
            comments: [],
            author: roommate1,
            choreSubcategory: .cooking
        ),
        Post(
            id: UUID(),
            homeID: home.id,
            userID: roommate2.id,
            category: .chore,
            text: "Took the trash out, you're welcome 🗑️",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-8 * 3600),
            reactions: nil,
            comments: [],
            author: roommate2,
            choreSubcategory: .trash
        ),
        Post(
            id: UUID(),
            homeID: home.id,
            userID: user.id,
            category: .chore,
            text: "Scrubbed both bathrooms. They sparkle ✨",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-24 * 3600),
            reactions: nil,
            comments: [],
            author: user,
            choreSubcategory: .bathrooms
        ),
        Post(
            id: UUID(),
            homeID: home.id,
            userID: roommate1.id,
            category: .chore,
            text: "Did two loads of laundry including everyone's stuff 👕",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-30 * 3600),
            reactions: nil,
            comments: [],
            author: roommate1,
            choreSubcategory: .laundry
        ),
        Post(
            id: UUID(),
            homeID: home.id,
            userID: roommate2.id,
            category: .chore,
            text: "Got groceries for the week 🛒",
            imageURL: nil,
            isDraft: false,
            createdAt: Date().addingTimeInterval(-48 * 3600),
            reactions: nil,
            comments: [],
            author: roommate2,
            choreSubcategory: .groceries
        ),
        requestPost
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

    static let subscriptions: [Subscription] = [
        Subscription(
            id: UUID(), homeID: home.id, createdByID: user.id,
            serviceName: "Netflix", serviceIcon: "📺",
            monthlyCost: 15.99, billingDay: 15,
            members: [
                SubscriptionMember(id: UUID(), subscriptionID: UUID(), userID: user.id, user: user),
                SubscriptionMember(id: UUID(), subscriptionID: UUID(), userID: roommate1.id, user: roommate1)
            ],
            createdAt: Date()
        ),
        Subscription(
            id: UUID(), homeID: home.id, createdByID: roommate1.id,
            serviceName: "Spotify", serviceIcon: "🎵",
            monthlyCost: 9.99, billingDay: 1,
            members: [
                SubscriptionMember(id: UUID(), subscriptionID: UUID(), userID: roommate1.id, user: roommate1),
                SubscriptionMember(id: UUID(), subscriptionID: UUID(), userID: roommate2.id, user: roommate2),
                SubscriptionMember(id: UUID(), subscriptionID: UUID(), userID: user.id, user: user)
            ],
            createdAt: Date()
        )
    ]

    static let spendLogs: [SpendLog] = [
        SpendLog(id: UUID(), homeID: home.id, userID: roommate1.id, amount: 45.20, category: .food, note: "Whole Foods run 🛒", createdAt: Date().addingTimeInterval(-86400), user: roommate1),
        SpendLog(id: UUID(), homeID: home.id, userID: user.id, amount: 18.50, category: .household, note: "Cleaning supplies 🧹", createdAt: Date().addingTimeInterval(-7200), user: user),
        SpendLog(id: UUID(), homeID: home.id, userID: roommate2.id, amount: 120.00, category: .utilities, note: "Electric bill ⚡", createdAt: Date().addingTimeInterval(-3 * 86400), user: roommate2)
    ]

    static let metrics: [UserMetrics] = [
        UserMetrics(id: UUID(), userID: roommate1.id, homeID: home.id, choresDone: 12, totalSpent: 45.0, lastPostAt: Date().addingTimeInterval(-3600), user: roommate1),
        UserMetrics(id: UUID(), userID: user.id, homeID: home.id, choresDone: 8, totalSpent: 18.50, lastPostAt: Date().addingTimeInterval(-7200), user: user),
        UserMetrics(id: UUID(), userID: roommate2.id, homeID: home.id, choresDone: 1, totalSpent: 0, lastPostAt: Date().addingTimeInterval(-5 * 86400), user: roommate2)
    ]

    static let toiletPaperReminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000060")!
    static let dishSoapReminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000061")!

    static let reminderGrabs: [ReminderGrab] = [
        ReminderGrab(id: UUID(), reminderID: toiletPaperReminderID, userID: user.id,
                     grabbedAt: Date().addingTimeInterval(-15 * 86400), user: user),
        ReminderGrab(id: UUID(), reminderID: toiletPaperReminderID, userID: roommate1.id,
                     grabbedAt: Date().addingTimeInterval(-29 * 86400), user: roommate1),
        ReminderGrab(id: UUID(), reminderID: toiletPaperReminderID, userID: roommate2.id,
                     grabbedAt: Date().addingTimeInterval(-43 * 86400), user: roommate2),
    ]

    static let reminders: [HouseholdReminder] = [
        HouseholdReminder(
            id: toiletPaperReminderID,
            homeID: home.id,
            name: "Toilet Paper",
            emoji: "🧻",
            intervalDays: 14,
            lastClearedAt: Date().addingTimeInterval(-15 * 86400),
            lastClearedByUserID: user.id,
            lastClearedByUser: user,
            createdAt: Date(),
            createdByUserID: user.id,
            currentClaimerID: nil,
            currentClaimerUser: nil,
            grabs: reminderGrabs.filter { $0.reminderID == toiletPaperReminderID }
        ),
        HouseholdReminder(
            id: dishSoapReminderID,
            homeID: home.id,
            name: "Dish Soap",
            emoji: "🍶",
            intervalDays: 30,
            lastClearedAt: nil,
            lastClearedByUserID: nil,
            lastClearedByUser: nil,
            createdAt: Date(),
            createdByUserID: user.id,
            currentClaimerID: nil,
            currentClaimerUser: nil,
            grabs: []
        )
    ]

    static var feedItems: [FeedItem] {
        var items: [FeedItem] = posts.map { .post($0) }
        items += stickyNotes.map { .stickyNote($0) }
        return items.sorted { $0.createdAt > $1.createdAt }
    }
}
#endif
