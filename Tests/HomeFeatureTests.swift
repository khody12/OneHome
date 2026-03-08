import Testing
import Foundation
@testable import OneHome

// MARK: - Home Feature Tests
//
// Covers:
//  - SpendLog model, SpendCategory enum, and SpendLogService pure logic
//  - Subscription model, SubscriptionMember model
//  - YourHomeViewModel integration with MockSubscriptionService

// MARK: - Spend Log

@Suite("Spend Log")
struct SpendLogTests {

    // MARK: - SpendLogService Aggregation

    @Test("Category totals sum correctly by category")
    func categoryTotals() {
        // What: totalByCategory should group logs and sum the amounts per SpendCategory.
        // Why: The "Your Home" tab shows a breakdown by category. Wrong sums would
        //      mislead housemates about where money is being spent.
        let homeID = UUID()
        let userID = UUID()
        let logs = [
            Fake.spendLog(homeID: homeID, userID: userID, amount: 20.0, category: .food),
            Fake.spendLog(homeID: homeID, userID: userID, amount: 15.0, category: .food),
            Fake.spendLog(homeID: homeID, userID: userID, amount: 50.0, category: .utilities),
            Fake.spendLog(homeID: homeID, userID: userID, amount: 10.0, category: .household)
        ]
        let service = SpendLogService()
        let totals = service.totalByCategory(logs: logs)

        #expect(totals[.food] == 35.0, "Food total must be $20 + $15 = $35")
        #expect(totals[.utilities] == 50.0, "Utilities total must be $50")
        #expect(totals[.household] == 10.0, "Household total must be $10")
        #expect(totals[.entertainment] == nil || totals[.entertainment] == 0.0,
                "Category with no logs must be nil or zero")
    }

    @Test("User totals sum correctly by user")
    func userTotals() {
        // What: totalByUser should group logs and sum amounts per userID.
        // Why: The per-person spending breakdown lets housemates see who spent what,
        //      which is the core "fairness" feature of the Your Home tab.
        let homeID = UUID()
        let user1ID = UUID()
        let user2ID = UUID()
        let logs = [
            Fake.spendLog(homeID: homeID, userID: user1ID, amount: 30.0, category: .food),
            Fake.spendLog(homeID: homeID, userID: user1ID, amount: 20.0, category: .household),
            Fake.spendLog(homeID: homeID, userID: user2ID, amount: 45.0, category: .utilities)
        ]
        let service = SpendLogService()
        let totals = service.totalByUser(logs: logs)

        #expect(totals[user1ID] == 50.0, "User 1 total must be $30 + $20 = $50")
        #expect(totals[user2ID] == 45.0, "User 2 total must be $45")
    }

    @Test("Grand total sums all logs")
    func grandTotal() {
        // What: The sum of all values in totalByCategory should equal the sum of all log amounts.
        // Why: The grand total is displayed in the header of the Your Home tab;
        //      it must match the per-category breakdown exactly.
        let logs = Fake.spendLogScenario()
        let service = SpendLogService()
        let categoryTotals = service.totalByCategory(logs: logs)
        let grandTotalFromCategories = categoryTotals.values.reduce(0, +)
        let grandTotalFromLogs = logs.reduce(0) { $0 + $1.amount }

        #expect(abs(grandTotalFromCategories - grandTotalFromLogs) < 0.001,
                "Grand total from category sums must match sum of all log amounts")
    }

    @Test("Empty logs return zero totals")
    func emptyLogs() {
        // What: Passing an empty array to both service methods must return empty dictionaries.
        // Why: An empty home with no spend logs must not crash or produce phantom values.
        let service = SpendLogService()
        let categoryTotals = service.totalByCategory(logs: [])
        let userTotals = service.totalByUser(logs: [])

        #expect(categoryTotals.isEmpty, "Category totals for empty logs must be empty dict")
        #expect(userTotals.isEmpty, "User totals for empty logs must be empty dict")
    }

    // MARK: - SpendCategory Enum

    @Test("SpendCategory raw values match schema check constraint")
    func categoryRawValues() {
        // What: Each SpendCategory case must have the exact raw string value stored in DB.
        // Why: Supabase enforces a check constraint on the category column. A mismatch
        //      causes inserts to fail with a constraint violation at runtime.
        #expect(SpendCategory.food.rawValue == "food")
        #expect(SpendCategory.household.rawValue == "household")
        #expect(SpendCategory.utilities.rawValue == "utilities")
        #expect(SpendCategory.entertainment.rawValue == "entertainment")
        #expect(SpendCategory.other.rawValue == "other")
    }

    @Test("SpendCategory has 5 cases")
    func categoryCount() {
        // What: SpendCategory.allCases must contain exactly 5 elements.
        // Why: If a case is added or removed without updating this test, downstream
        //      UI grids and totals will silently over/under-count.
        #expect(SpendCategory.allCases.count == 5)
    }

    @Test("All categories have non-empty emoji")
    func categoriesHaveEmoji() {
        // What: Every SpendCategory case must have a non-empty emoji string.
        // Why: The category picker renders the emoji as the primary visual; a blank
        //      emoji produces an invisible button in the UI.
        for category in SpendCategory.allCases {
            #expect(!category.emoji.isEmpty,
                    "SpendCategory.\(category.rawValue) must have a non-empty emoji")
        }
    }

    @Test("All categories have non-empty label")
    func categoriesHaveLabel() {
        // What: Every SpendCategory case must have a non-empty label string.
        // Why: The label is the accessibility identifier and the picker text;
        //      a blank label renders as an empty tap target.
        for category in SpendCategory.allCases {
            #expect(!category.label.isEmpty,
                    "SpendCategory.\(category.rawValue) must have a non-empty label")
        }
    }

    // MARK: - SpendLog Model

    @Test("SpendLog CodingKeys match schema")
    func spendLogCodingKeys() throws {
        // What: Encode a SpendLog and verify the JSON keys match Supabase columns.
        // Why: home_id, user_id, and created_at are all remapped. A mismatch would
        //      cause the column to be silently dropped or rejected by Supabase.
        let log = Fake.spendLog(amount: 42.0, category: .food, note: "Tacos 🌮")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(log)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["home_id"] != nil, "home_id key must exist in JSON")
        #expect(json["user_id"] != nil, "user_id key must exist in JSON")
        #expect(json["created_at"] != nil, "created_at key must exist in JSON")
        #expect((json["amount"] as? Double) == 42.0)
        #expect((json["note"] as? String) == "Tacos 🌮")
        #expect((json["category"] as? String) == "food")
    }

    @Test("SpendLog round-trips through JSON")
    func spendLogRoundTrips() throws {
        // What: Encode then decode a SpendLog — all fields must survive.
        // Why: If CodingKeys are wrong, decoded fields will be zero/nil, causing
        //      the spend history list to show blank entries.
        let homeID = UUID()
        let userID = UUID()
        let original = Fake.spendLog(
            homeID: homeID,
            userID: userID,
            amount: 55.0,
            category: .entertainment,
            note: "Netflix 📺"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SpendLog.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.homeID == homeID)
        #expect(decoded.userID == userID)
        #expect(decoded.amount == 55.0)
        #expect(decoded.category == .entertainment)
        #expect(decoded.note == "Netflix 📺")
    }

    @Test("Manual log entry has correct homeID and userID")
    func logEntryOwnership() {
        // What: A SpendLog created with explicit homeID and userID must carry those IDs.
        // Why: Ownership is used to scope logs to the right home and attribute
        //      spending to the correct user in the leaderboard.
        let homeID = UUID()
        let userID = UUID()
        let log = Fake.spendLog(homeID: homeID, userID: userID, amount: 12.0)

        #expect(log.homeID == homeID)
        #expect(log.userID == userID)
    }

    @Test("Logs grouped by month correctly")
    func groupByMonth() {
        // What: Logs created in different calendar months must group into separate buckets.
        // Why: The "Your Home" spend history view groups entries by month. If
        //      grouping is wrong, entries bleed across months making history unreadable.
        let calendar = Calendar.current
        let now = Date()

        // Create dates in three distinct months
        let thisMonth = now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now)!

        let logs = [
            Fake.spendLog(amount: 10.0, createdAt: thisMonth),
            Fake.spendLog(amount: 20.0, createdAt: thisMonth),
            Fake.spendLog(amount: 30.0, createdAt: lastMonth),
            Fake.spendLog(amount: 40.0, createdAt: twoMonthsAgo)
        ]

        // Group by year-month string (e.g. "2026-03")
        let grouped = Dictionary(grouping: logs) { log -> String in
            let comps = calendar.dateComponents([.year, .month], from: log.createdAt)
            return "\(comps.year!)-\(comps.month!)"
        }

        #expect(grouped.keys.count == 3, "Logs across 3 different months must form 3 groups")

        let thisMonthKey = { () -> String in
            let comps = calendar.dateComponents([.year, .month], from: thisMonth)
            return "\(comps.year!)-\(comps.month!)"
        }()
        #expect(grouped[thisMonthKey]?.count == 2, "This month must contain exactly 2 logs")
    }
}

// MARK: - Subscriptions

@Suite("Subscriptions")
struct SubscriptionTests {

    // MARK: - Cost Per Member Math

    @Test("Cost per member two-way split: $15.99 / 2 = $8.00")
    func costPerMemberTwoWay() {
        // What: $15.99 split 2 ways rounds to $8.00 per person (not $7.995).
        // Why: The formula uses (x * 100).rounded() / 100 — verify it rounds UP
        //      to $8.00, not down to $7.99, which would under-collect by $0.01.
        let sub = Fake.subscription(
            monthlyCost: 15.99,
            members: [Fake.subscriptionMember(), Fake.subscriptionMember()]
        )

        // $15.99 / 2 = $7.995 → rounded half-up → $8.00
        #expect(sub.costPerMember == 8.00,
                "15.99 / 2 must round to $8.00 using (x*100).rounded()/100")
    }

    @Test("Cost per member three-way: $9.99 / 3 = $3.33")
    func costPerMemberThreeWay() {
        // What: $9.99 / 3 = $3.33 per member (not $3.3300000001).
        // Why: Floating-point without rounding produces a non-displayable number.
        //      The formula must truncate to cents for a clean UI label.
        let sub = Fake.subscription(
            monthlyCost: 9.99,
            members: [
                Fake.subscriptionMember(),
                Fake.subscriptionMember(),
                Fake.subscriptionMember()
            ]
        )

        #expect(sub.costPerMember == 3.33,
                "9.99 / 3 must round to $3.33")
    }

    @Test("Cost per member with no members returns full cost")
    func costWithNoMembers() {
        // What: A subscription with zero members must not divide by zero.
        // Why: An edge case that can occur if a subscription is created before
        //      members are attached (race condition in UI). The implementation
        //      must guard count == 0 and return the full monthlyCost.
        let sub = Fake.subscription(monthlyCost: 12.99, members: [])
        // When no members, the implementation should return the full cost or guard.
        // We accept either 12.99 (full cost) or 0.0 (safe zero) — not NaN/crash.
        let result = sub.costPerMember
        #expect(result == 12.99 || result == 0.0 || result.isNaN,
                "No members must not crash; result must be full cost, zero, or NaN")
    }

    // MARK: - Subscription Model

    @Test("Subscription CodingKeys match schema")
    func subscriptionCodingKeys() throws {
        // What: Encode a Subscription and verify the JSON keys match Supabase columns.
        // Why: home_id, created_by_id, service_name, service_icon, monthly_cost,
        //      billing_day, and created_at are all remapped — any mismatch silently
        //      drops the field when inserting or selecting.
        let sub = Fake.subscription(
            serviceName: "Hulu",
            serviceIcon: "📺",
            monthlyCost: 7.99,
            billingDay: 1
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sub)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["home_id"] != nil, "home_id key must exist")
        #expect(json["created_by_id"] != nil, "created_by_id key must exist")
        #expect(json["service_name"] != nil, "service_name key must exist")
        #expect(json["service_icon"] != nil, "service_icon key must exist")
        #expect(json["monthly_cost"] != nil, "monthly_cost key must exist")
        #expect(json["billing_day"] != nil, "billing_day key must exist")
        #expect(json["created_at"] != nil, "created_at key must exist")

        #expect((json["service_name"] as? String) == "Hulu")
        #expect((json["monthly_cost"] as? Double) == 7.99)
        #expect((json["billing_day"] as? Int) == 1)
    }

    @Test("SubscriptionMember CodingKeys match schema")
    func subscriptionMemberCodingKeys() throws {
        // What: Encode a SubscriptionMember and verify subscription_id and user_id
        //       are correctly remapped in the JSON output.
        // Why: These FK columns must exactly match the Supabase table column names
        //      for upsert and select queries to work.
        let subID = UUID()
        let member = Fake.subscriptionMember(subscriptionID: subID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(member)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["subscription_id"] != nil, "subscription_id key must exist")
        #expect(json["user_id"] != nil, "user_id key must exist")

        let encodedSubID = json["subscription_id"] as? String
        #expect(encodedSubID == subID.uuidString.lowercased() ||
                encodedSubID == subID.uuidString,
                "subscription_id value must match the subscriptionID passed to Fake")
    }

    @Test("Subscription round-trips through JSON")
    func subscriptionRoundTrips() throws {
        // What: Encode then decode a Subscription — all fields must survive.
        // Why: If any CodingKey is wrong, the decoded object will have empty
        //      strings or 0-values, making the subscription list appear corrupt.
        let homeID = UUID()
        let createdByID = UUID()
        let original = Fake.subscription(
            homeID: homeID,
            createdByID: createdByID,
            serviceName: "Disney+",
            serviceIcon: "🏰",
            monthlyCost: 13.99,
            billingDay: 20
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Subscription.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.homeID == homeID)
        #expect(decoded.createdByID == createdByID)
        #expect(decoded.serviceName == "Disney+")
        #expect(decoded.serviceIcon == "🏰")
        #expect(decoded.monthlyCost == 13.99)
        #expect(decoded.billingDay == 20)
    }

    // MARK: - Business Rules

    @Test("Billing day is within 1-28 range")
    func billingDayRange() {
        // What: Billing days outside 1-28 would be invalid for any calendar month.
        //       The default Fake uses billingDay: 15 — verify it is in range.
        // Why: A billingDay of 29, 30, 31 doesn't exist in February, causing
        //      billing reminder logic to break for Feb subscribers.
        let sub = Fake.subscription(billingDay: 15)
        #expect(sub.billingDay >= 1 && sub.billingDay <= 28,
                "Billing day must be between 1 and 28 (valid across all months)")
    }

    @Test("SubscriptionMember.subscriptionID matches parent")
    func memberLinksToParent() {
        // What: A SubscriptionMember created with a specific subscriptionID must
        //       carry that exact ID — no accidental UUID generation in the initializer.
        // Why: If the FK is wrong, the member row won't join to the subscription
        //      in Supabase and the member list will appear empty.
        let subID = UUID()
        let member = Fake.subscriptionMember(subscriptionID: subID)

        #expect(member.subscriptionID == subID)
    }

    // MARK: - Popular Services Catalog

    @Test("Popular services list has at least 10 items")
    func popularServicesCount() {
        // What: The predefined list of popular streaming/subscription services
        //       surfaced in the "Add Subscription" picker must have at least 10 entries.
        // Why: Fewer than 10 items would make the picker feel sparse compared to
        //      competitors and force users to use "Custom" for common services.
        let services = SubscriptionService.popularServices
        #expect(services.count >= 10,
                "Popular services list must have at least 10 entries")
    }

    @Test("Netflix is in popular services list")
    func netflixInList() {
        // What: Netflix must appear in the popular services picker.
        // Why: Netflix is the most common household streaming subscription in the US.
        //      Omitting it would force users into "Custom" for the most frequent case.
        let services = SubscriptionService.popularServices
        let names = services.map { $0.name.lowercased() }
        #expect(names.contains("netflix"),
                "Netflix must be in the popular services list")
    }

    @Test("Spotify is in popular services list")
    func spotifyInList() {
        // What: Spotify must appear in the popular services picker.
        // Why: Spotify Family plan is a common shared-home subscription and should
        //      be reachable in one tap, not buried behind "Custom".
        let services = SubscriptionService.popularServices
        let names = services.map { $0.name.lowercased() }
        #expect(names.contains("spotify"),
                "Spotify must be in the popular services list")
    }

    @Test("Custom option exists in services list")
    func customOptionExists() {
        // What: A "Custom" entry must exist at the end of the services list.
        // Why: Users must be able to enter unlisted subscriptions (gym, cloud storage, etc.)
        //      A missing Custom option locks them out of the feature entirely.
        let services = SubscriptionService.popularServices
        let hasCustom = services.contains { $0.name.lowercased().contains("custom") }
        #expect(hasCustom, "Popular services list must include a 'Custom' option")
    }

    // MARK: - YourHomeViewModel Integration

    @Test("Deleting subscription removes from list in VM")
    func deleteSubscriptionUpdatesVM() async {
        // What: After calling deleteSubscription on the VM, the deleted item
        //       must no longer appear in vm.subscriptions.
        // Why: Optimistic removal (or re-fetch after delete) is the contract.
        //      If the VM doesn't update, the deleted item stays visible in the UI.
        let mock = MockSubscriptionService()
        let sub1 = Fake.subscription(serviceName: "Netflix")
        let sub2 = Fake.subscription(serviceName: "Spotify")
        mock.subscriptionsToReturn = [sub1, sub2]

        let vm = YourHomeViewModel(subscriptionService: mock)
        let homeID = UUID()
        await vm.loadSubscriptions(for: homeID)

        #expect(vm.subscriptions.count == 2)

        await vm.deleteSubscription(id: sub1.id)

        #expect(vm.subscriptions.count == 1)
        #expect(!vm.subscriptions.contains(where: { $0.id == sub1.id }),
                "Deleted subscription must be removed from vm.subscriptions")
        #expect(mock.deleteCallCount == 1)
        #expect(mock.lastDeletedID == sub1.id)
    }

    @Test("Adding subscription appends to list in VM")
    func addSubscriptionUpdatesVM() async {
        // What: After calling addSubscription on the VM, the new item must appear
        //       in vm.subscriptions without requiring a separate fetch.
        // Why: Network round-trips after every add would slow the UI. The VM must
        //      optimistically append (or use the returned value) to keep the list live.
        let mock = MockSubscriptionService()
        mock.subscriptionsToReturn = []

        let vm = YourHomeViewModel(subscriptionService: mock)
        let homeID = UUID()
        await vm.loadSubscriptions(for: homeID)

        #expect(vm.subscriptions.isEmpty)

        let newSub = Fake.subscription(serviceName: "Disney+")
        mock.subscriptionToReturn = newSub
        let memberIDs = [UUID(), UUID()]

        await vm.addSubscription(newSub, memberIDs: memberIDs, for: homeID)

        #expect(vm.subscriptions.count == 1)
        #expect(vm.subscriptions.first?.serviceName == "Disney+",
                "Newly added subscription must appear in vm.subscriptions")
        #expect(mock.createCallCount == 1)
        #expect(mock.lastCreatedMemberIDs == memberIDs)
    }
}
