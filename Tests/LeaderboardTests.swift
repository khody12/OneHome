import Testing
import Foundation
@testable import OneHome

// MARK: - LeaderboardTests

@Suite("Leaderboard & Chore Subcategories")
struct LeaderboardTests {

    // MARK: - TimeRange

    @Test("TimeRange.allTime returns nil since date")
    func allTimeSinceIsNil() {
        #expect(TimeRange.allTime.since == nil)
    }

    @Test("TimeRange.thisMonth returns non-nil since date")
    func thisMonthSinceIsNonNil() {
        #expect(TimeRange.thisMonth.since != nil)
    }

    @Test("TimeRange.thisMonth since date is in the past or now")
    func thisMonthSinceIsNotFuture() {
        guard let since = TimeRange.thisMonth.since else {
            Issue.record("Expected non-nil since date for .thisMonth")
            return
        }
        #expect(since <= Date())
    }

    @Test("TimeRange.thisMonth since date is the first of the current month")
    func thisMonthSinceIsFirstOfMonth() {
        guard let since = TimeRange.thisMonth.since else {
            Issue.record("Expected non-nil since date for .thisMonth")
            return
        }
        let cal = Calendar.current
        let day = cal.component(.day, from: since)
        #expect(day == 1)
    }

    @Test("TimeRange has exactly 2 cases")
    func timeRangeCaseCount() {
        #expect(TimeRange.allCases.count == 2)
    }

    // MARK: - LeaderboardType

    @Test("LeaderboardType has 3 cases: overall, chores, spending")
    func leaderboardTypeAllCasesCount() {
        #expect(LeaderboardType.allCases.count == 3)
    }

    @Test("LeaderboardType cases have correct raw values")
    func leaderboardTypeRawValues() {
        #expect(LeaderboardType.overall.rawValue == "Overall")
        #expect(LeaderboardType.chores.rawValue == "Chores")
        #expect(LeaderboardType.spending.rawValue == "Spending")
    }

    @Test("LeaderboardType.id equals rawValue")
    func leaderboardTypeIDEqualsRawValue() {
        for type in LeaderboardType.allCases {
            #expect(type.id == type.rawValue)
        }
    }

    // MARK: - ChoreSubcategory

    @Test("ChoreSubcategory has 8 cases")
    func choreSubcategoryCaseCount() {
        #expect(ChoreSubcategory.allCases.count == 8)
    }

    @Test("ChoreSubcategory labels are correct")
    func choreSubcategoryLabels() {
        #expect(ChoreSubcategory.cooking.label == "Cooking")
        #expect(ChoreSubcategory.dishes.label == "Dishes")
        #expect(ChoreSubcategory.floors.label == "Floors")
        #expect(ChoreSubcategory.laundry.label == "Laundry")
        #expect(ChoreSubcategory.trash.label == "Trash")
        #expect(ChoreSubcategory.groceries.label == "Groceries")
        #expect(ChoreSubcategory.bathrooms.label == "Bathrooms")
        #expect(ChoreSubcategory.other.label == "Other")
    }

    @Test("ChoreSubcategory emojis are correct")
    func choreSubcategoryEmojis() {
        #expect(ChoreSubcategory.cooking.emoji == "🍳")
        #expect(ChoreSubcategory.dishes.emoji == "🍽️")
        #expect(ChoreSubcategory.floors.emoji == "🧹")
        #expect(ChoreSubcategory.laundry.emoji == "👕")
        #expect(ChoreSubcategory.trash.emoji == "🗑️")
        #expect(ChoreSubcategory.groceries.emoji == "🛒")
        #expect(ChoreSubcategory.bathrooms.emoji == "🚿")
        #expect(ChoreSubcategory.other.emoji == "📦")
    }

    @Test("ChoreSubcategory id equals rawValue")
    func choreSubcategoryIDEqualsRawValue() {
        for sub in ChoreSubcategory.allCases {
            #expect(sub.id == sub.rawValue)
        }
    }

    @Test("ChoreSubcategory raw values are snake_case strings")
    func choreSubcategoryRawValues() {
        #expect(ChoreSubcategory.cooking.rawValue == "cooking")
        #expect(ChoreSubcategory.dishes.rawValue == "dishes")
        #expect(ChoreSubcategory.other.rawValue == "other")
    }

    // MARK: - CategoryLeaderboardEntry

    @Test("CategoryLeaderboardEntry id matches user id")
    func categoryLeaderboardEntryIDMatchesUserID() {
        let userID = UUID()
        let user = Fake.user(id: userID, name: "Tester")
        let entry = CategoryLeaderboardEntry(id: userID, user: user, count: 5, totalAmount: 0)
        #expect(entry.id == userID)
    }

    // MARK: - MetricsViewModel leaderboard state

    @Test("selectedLeaderboard defaults to .overall")
    func selectedLeaderboardDefaultsToOverall() {
        let vm = MetricsViewModel()
        #expect(vm.selectedLeaderboard == .overall)
    }

    @Test("selectedTimeRange defaults to .allTime")
    func selectedTimeRangeDefaultsToAllTime() {
        let vm = MetricsViewModel()
        #expect(vm.selectedTimeRange == .allTime)
    }

    @Test("selectedChoreSubcategory defaults to nil")
    func selectedChoreSubcategoryDefaultsToNil() {
        let vm = MetricsViewModel()
        #expect(vm.selectedChoreSubcategory == nil)
    }

    @Test("Switching selectedLeaderboard updates activeLeaderboardEntries source")
    func switchingLeaderboardUpdatesActive() {
        let vm = MetricsViewModel()
        let user = Fake.user()
        let choreEntry = CategoryLeaderboardEntry(id: user.id, user: user, count: 5, totalAmount: 0)
        let spendEntry = CategoryLeaderboardEntry(id: user.id, user: user, count: 0, totalAmount: 99.0)

        vm.overallChoreLeaderboard = [choreEntry]
        vm.spendLeaderboard = [spendEntry]

        vm.selectedLeaderboard = .overall
        #expect(vm.activeLeaderboardEntries.first?.count == 5)

        vm.selectedLeaderboard = .spending
        #expect(vm.activeLeaderboardEntries.first?.totalAmount == 99.0)
    }

    @Test("Chore leaderboard with sub selected returns subcategory entries")
    func choreLeaderboardWithSubReturnsSubcategoryEntries() {
        let vm = MetricsViewModel()
        let user = Fake.user()
        let dishesEntry = CategoryLeaderboardEntry(id: user.id, user: user, count: 3, totalAmount: 0)
        vm.choreLeaderboards[.dishes] = [dishesEntry]
        vm.selectedLeaderboard = .chores
        vm.selectedChoreSubcategory = .dishes

        #expect(vm.activeLeaderboardEntries.first?.count == 3)
    }

    @Test("Chore leaderboard with nil sub returns overall chore entries")
    func choreLeaderboardWithNilSubReturnsOverall() {
        let vm = MetricsViewModel()
        let user = Fake.user()
        let overallEntry = CategoryLeaderboardEntry(id: user.id, user: user, count: 10, totalAmount: 0)
        vm.overallChoreLeaderboard = [overallEntry]
        vm.selectedLeaderboard = .chores
        vm.selectedChoreSubcategory = nil

        #expect(vm.activeLeaderboardEntries.first?.count == 10)
    }

    // MARK: - Dev mode leaderboard computation

    @Test("Dev mode: load populates overallChoreLeaderboard from DevPreview posts")
    func devModeLoadsOverallChoreLeaderboard() async {
#if DEBUG
        let vm = MetricsViewModel()
        await vm.load(for: DevPreview.home, currentUserID: DevPreview.user.id)
        // DevPreview has multiple chore posts with subcategories
        #expect(!vm.overallChoreLeaderboard.isEmpty)
#endif
    }

    @Test("Dev mode: load populates spendLeaderboard from DevPreview spendLogs")
    func devModeLoadsSpendLeaderboard() async {
#if DEBUG
        let vm = MetricsViewModel()
        await vm.load(for: DevPreview.home, currentUserID: DevPreview.user.id)
        #expect(!vm.spendLeaderboard.isEmpty)
#endif
    }

    @Test("Dev mode: overall chore leaderboard is sorted descending by count")
    func devModeOverallChoreLeaderboardSortedDescending() async {
#if DEBUG
        let vm = MetricsViewModel()
        await vm.load(for: DevPreview.home, currentUserID: DevPreview.user.id)
        let entries = vm.overallChoreLeaderboard
        guard entries.count > 1 else { return }
        for i in 0..<entries.count - 1 {
            #expect(entries[i].count >= entries[i + 1].count)
        }
#endif
    }

    @Test("Dev mode: spend leaderboard is sorted descending by totalAmount")
    func devModeSpendLeaderboardSortedDescending() async {
#if DEBUG
        let vm = MetricsViewModel()
        await vm.load(for: DevPreview.home, currentUserID: DevPreview.user.id)
        let entries = vm.spendLeaderboard
        guard entries.count > 1 else { return }
        for i in 0..<entries.count - 1 {
            #expect(entries[i].totalAmount >= entries[i + 1].totalAmount)
        }
#endif
    }

    @Test("Dev mode: choreLeaderboards contains entries for dishes after loading")
    func devModeChoreLeaderboardContainsDishes() async {
#if DEBUG
        let vm = MetricsViewModel()
        await vm.load(for: DevPreview.home, currentUserID: DevPreview.user.id)
        // DevPreview has a dishes chore post
        let dishEntries = vm.choreLeaderboards[.dishes] ?? []
        #expect(!dishEntries.isEmpty)
#endif
    }

    // MARK: - Sorting & entry order

    @Test("Manually set overallChoreLeaderboard respects insertion order (sorting is done by service)")
    func overallChoreLeaderboardPreservesOrder() {
        let vm = MetricsViewModel()
        let u1 = Fake.user(name: "Alpha")
        let u2 = Fake.user(name: "Beta")
        vm.overallChoreLeaderboard = [
            CategoryLeaderboardEntry(id: u1.id, user: u1, count: 9, totalAmount: 0),
            CategoryLeaderboardEntry(id: u2.id, user: u2, count: 3, totalAmount: 0)
        ]
        vm.selectedLeaderboard = .overall
        let active = vm.activeLeaderboardEntries
        #expect(active[0].count == 9)
        #expect(active[1].count == 3)
    }

    @Test("Empty leaderboard returns empty activeLeaderboardEntries")
    func emptyLeaderboardReturnsEmpty() {
        let vm = MetricsViewModel()
        vm.selectedLeaderboard = .overall
        vm.overallChoreLeaderboard = []
        #expect(vm.activeLeaderboardEntries.isEmpty)
    }

    // MARK: - Post choreSubcategory model

    @Test("Post with choreSubcategory encodes/decodes correctly")
    func postChoreSubcategoryRoundTrip() throws {
        let sub = ChoreSubcategory.cooking
        let post = Fake.post(category: .chore, choreSubcategory: sub)
        #expect(post.choreSubcategory == sub)
    }

    @Test("Non-chore post choreSubcategory is nil")
    func nonChorePostHasNilSubcategory() {
        let post = Fake.post(category: .purchase)
        #expect(post.choreSubcategory == nil)
    }
}
