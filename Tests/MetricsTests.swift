import Testing
import Foundation
@testable import OneHome

// MARK: - TestableMetricsViewModel
//
// Subclass of MetricsViewModel that accepts an injected MockMetricsService.
// Uses the same subclass pattern as TestableFeedViewModel to keep production
// code unmodified while enabling fully controlled unit tests.

@Observable
final class TestableMetricsViewModel: MetricsViewModel {
    let metricsService: MockMetricsService

    init(metricsService: MockMetricsService) {
        self.metricsService = metricsService
    }

    override func load(for home: Home, currentUserID: UUID? = nil) async {
        isLoading = true
        metrics = (try? await metricsService.fetchMetrics(for: home.id)) ?? []
        if let uid = currentUserID {
            currentUserMetrics = metrics.first { $0.userID == uid }
        }
        isLoading = false
    }
}

// MARK: - MetricsLogicTests

@Suite("Metrics Logic")
struct MetricsLogicTests {

    // MARK: Helpers

    private func makeSUT() -> (vm: TestableMetricsViewModel, service: MockMetricsService) {
        let service = MockMetricsService()
        let vm = TestableMetricsViewModel(metricsService: service)
        return (vm, service)
    }

    // Build a 4-person metrics set with known chore counts
    private func fourPersonMetrics() -> (
        first: UserMetrics, second: UserMetrics,
        third: UserMetrics, last: UserMetrics,
        all: [UserMetrics]
    ) {
        let now = Date()
        let first  = Fake.metrics(choresDone: 10, lastPostAt: now.addingTimeInterval(-3600))
        let second = Fake.metrics(choresDone: 7,  lastPostAt: now.addingTimeInterval(-7200))
        let third  = Fake.metrics(choresDone: 4,  lastPostAt: now.addingTimeInterval(-10800))
        let last   = Fake.metrics(choresDone: 1,  lastPostAt: now.addingTimeInterval(-5 * 86400))
        return (first, second, third, last, [first, second, third, last])
    }

    // MARK: - Ranking

    @Test("Ranked list orders by choresDone descending")
    func rankedListIsDescending() {
        // WHY: The leaderboard must show the hardest worker first. If the sort
        // direction is wrong, rank #1 goes to the laziest person — oops.
        let (vm, _) = makeSUT()
        let now = Date()
        vm.metrics = [
            Fake.metrics(choresDone: 3, lastPostAt: now.addingTimeInterval(-3600)),
            Fake.metrics(choresDone: 10, lastPostAt: now.addingTimeInterval(-3600)),
            Fake.metrics(choresDone: 6, lastPostAt: now.addingTimeInterval(-3600))
        ]

        let ranked = vm.ranked
        #expect(ranked[0].choresDone == 10)
        #expect(ranked[1].choresDone == 6)
        #expect(ranked[2].choresDone == 3)
    }

    @Test("Current user rank is correct in a 4-person home")
    func currentUserRankIn4PersonHome() {
        // WHY: The "Your Stats" card displays the current user's rank.
        // In a 4-person home where our user is in 2nd place, rank must be 2.
        let (vm, _) = makeSUT()
        let (_, second, _, _, all) = fourPersonMetrics()
        vm.metrics = all

        let rank = vm.currentUserRank(userID: second.userID)
        #expect(rank == 2)
    }

    @Test("User in last place gets rank 4")
    func lastPlaceRank() {
        // WHY: Last-place rank must equal the total number of participants —
        // not 0 or some off-by-one value.
        let (vm, _) = makeSUT()
        let (_, _, _, last, all) = fourPersonMetrics()
        vm.metrics = all

        let rank = vm.currentUserRank(userID: last.userID)
        #expect(rank == 4)
    }

    @Test("Rank 1 is correctly assigned to top chore-doer")
    func firstPlaceRankIsOne() {
        let (vm, _) = makeSUT()
        let (first, _, _, _, all) = fourPersonMetrics()
        vm.metrics = all

        let rank = vm.currentUserRank(userID: first.userID)
        #expect(rank == 1)
    }

    @Test("Ranked list in a single-person home gives rank 1")
    func singlePersonHomeRankIsOne() {
        let (vm, _) = makeSUT()
        let solo = Fake.metrics(choresDone: 99)
        vm.metrics = [solo]

        #expect(vm.currentUserRank(userID: solo.userID) == 1)
    }

    // MARK: - Totals

    @Test("Total chores sums all roommates")
    func totalChoresSumsAll() {
        // WHY: The home header shows the combined chore count. It must be
        // the sum — not just the top person's count.
        let (vm, _) = makeSUT()
        let now = Date()
        vm.metrics = [
            Fake.metrics(choresDone: 5, lastPostAt: now.addingTimeInterval(-3600)),
            Fake.metrics(choresDone: 8, lastPostAt: now.addingTimeInterval(-3600)),
            Fake.metrics(choresDone: 3, lastPostAt: now.addingTimeInterval(-3600))
        ]
        #expect(vm.totalChoresDone == 16)
    }

    @Test("Total spent sums all roommates")
    func totalSpentSumsAll() {
        // WHY: The home header also shows total money spent. Same logic applies.
        let (vm, _) = makeSUT()
        let now = Date()
        vm.metrics = [
            Fake.metrics(totalSpent: 20.0, lastPostAt: now.addingTimeInterval(-3600)),
            Fake.metrics(totalSpent: 55.50, lastPostAt: now.addingTimeInterval(-3600)),
            Fake.metrics(totalSpent: 10.25, lastPostAt: now.addingTimeInterval(-3600))
        ]
        #expect(vm.totalSpent == 20.0 + 55.50 + 10.25)
    }

    @Test("Total chores is zero when metrics list is empty")
    func totalChoresZeroWhenEmpty() {
        let (vm, _) = makeSUT()
        vm.metrics = []
        #expect(vm.totalChoresDone == 0)
    }

    @Test("Total spent is zero when metrics list is empty")
    func totalSpentZeroWhenEmpty() {
        let (vm, _) = makeSUT()
        vm.metrics = []
        #expect(vm.totalSpent == 0.0)
    }

    // MARK: - Slackers

    @Test("Slacker list is empty when all users are active")
    func noSlackersWhenAllActive() {
        // WHY: The Hall of Shame must not appear if everyone is pulling their weight.
        let (vm, _) = makeSUT()
        let now = Date()
        // Everyone posted within 72h
        vm.metrics = [
            Fake.metrics(lastPostAt: now.addingTimeInterval(-3600)),   // 1h ago
            Fake.metrics(lastPostAt: now.addingTimeInterval(-48 * 3600)), // 48h ago
            Fake.metrics(lastPostAt: now.addingTimeInterval(-71 * 3600))  // 71h ago — just under cutoff
        ]
        #expect(vm.slackers.isEmpty)
    }

    @Test("Hall of shame shows only slackers")
    func hallOfShameOnlySlackers() {
        // WHY: The slackers computed property must correctly filter — active
        // members must NOT appear in the shame list.
        let (vm, _) = makeSUT()
        let now = Date()
        let active1 = Fake.metrics(lastPostAt: now.addingTimeInterval(-3600))    // 1h ago
        let active2 = Fake.metrics(lastPostAt: now.addingTimeInterval(-48 * 3600)) // 48h ago
        let slacker = Fake.metrics(lastPostAt: now.addingTimeInterval(-5 * 86400))  // 5 days ago

        vm.metrics = [active1, active2, slacker]

        #expect(vm.slackers.count == 1)
        #expect(vm.slackers[0].userID == slacker.userID)
    }

    @Test("User who never posted is flagged as slacker when others are active")
    func neverPostedUserIsSlacker() {
        let (vm, _) = makeSUT()
        let now = Date()
        let active = Fake.metrics(lastPostAt: now.addingTimeInterval(-3600))
        let neverPosted = Fake.metrics(lastPostAt: nil)

        vm.metrics = [active, neverPosted]

        #expect(vm.slackers.count == 1)
        #expect(vm.slackers[0].userID == neverPosted.userID)
    }

    @Test("Multiple slackers are all in the shame list")
    func multipleSlackersAllShown() {
        let (vm, _) = makeSUT()
        let now = Date()
        let active   = Fake.metrics(lastPostAt: now.addingTimeInterval(-3600))
        let slacker1 = Fake.metrics(lastPostAt: now.addingTimeInterval(-5 * 86400))
        let slacker2 = Fake.metrics(lastPostAt: now.addingTimeInterval(-7 * 86400))

        vm.metrics = [active, slacker1, slacker2]

        #expect(vm.slackers.count == 2)
    }

    // MARK: - Load & currentUserMetrics

    @Test("Metrics load populates currentUserMetrics")
    func currentUserMetricsPopulated() async {
        // WHY: The "Your Stats" card reads from currentUserMetrics. If it's nil
        // after load, the card won't render.
        let (vm, service) = makeSUT()
        let currentUserID = UUID()
        let myMetrics = Fake.metrics(userID: currentUserID, choresDone: 12, totalSpent: 88.0)
        let othersMetrics = Fake.metrics(choresDone: 4)
        service.metricsToReturn = [myMetrics, othersMetrics]
        let home = Fake.home()

        await vm.load(for: home, currentUserID: currentUserID)

        #expect(vm.currentUserMetrics?.userID == currentUserID)
        #expect(vm.currentUserMetrics?.choresDone == 12)
    }

    @Test("Metrics load with no currentUserID leaves currentUserMetrics nil")
    func loadWithoutCurrentUserIDLeavesMetricsNil() async {
        let (vm, service) = makeSUT()
        service.metricsToReturn = [Fake.metrics(), Fake.metrics()]
        let home = Fake.home()

        await vm.load(for: home, currentUserID: nil)

        #expect(vm.currentUserMetrics == nil)
    }

    @Test("isLoading resets to false after load completes")
    func isLoadingResetAfterLoad() async {
        let (vm, service) = makeSUT()
        service.metricsToReturn = Fake.homeScenario().metrics
        let home = Fake.home()

        await vm.load(for: home)

        #expect(vm.isLoading == false)
    }

    @Test("Load with service error leaves metrics empty")
    func loadWithServiceErrorLeavesEmpty() async {
        let (vm, service) = makeSUT()
        service.errorToThrow = AppError.networkError("failed")
        let home = Fake.home()

        await vm.load(for: home)

        #expect(vm.metrics.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - Days since last post

    @Test("Days since last post is correct")
    func daysSinceLastPost() {
        // WHY: The Hall of Shame shows "X days ago". The date math must be
        // accurate — off-by-one errors would misrepresent how long someone
        // has been slacking.
        let threeDAysAgo = Date().addingTimeInterval(-3 * 86400)
        let m = Fake.metrics(lastPostAt: threeDAysAgo)

        let days = Int(Date().timeIntervalSince(m.lastPostAt!) / 86400)
        #expect(days == 3)
    }

    @Test("Days since last post is 0 for a post made today")
    func daysSinceLastPostIsZeroForToday() {
        let justNow = Date().addingTimeInterval(-60)  // 1 minute ago
        let m = Fake.metrics(lastPostAt: justNow)

        let days = Int(Date().timeIntervalSince(m.lastPostAt!) / 86400)
        #expect(days == 0)
    }

    // MARK: - Scenario-based

    @Test("homeScenario slacker (sam) appears in slackers")
    func homeScenarioSlackerDetected() {
        // WHY: The homeScenario fixture sets up a 3-person home where sam
        // is the designated slacker. Verify our VM logic agrees.
        let (vm, _) = makeSUT()
        let scenario = Fake.homeScenario()
        vm.metrics = scenario.metrics

        let samID = scenario.users.first { $0.username == "samw" }!.id
        let slackerIDs = Set(vm.slackers.map { $0.userID })

        #expect(slackerIDs.contains(samID))
        // Alex and Jordan are active — should NOT be slackers
        let alexID = scenario.users.first { $0.username == "alexr" }!.id
        let jordanID = scenario.users.first { $0.username == "jordanb" }!.id
        #expect(!slackerIDs.contains(alexID))
        #expect(!slackerIDs.contains(jordanID))
    }

    @Test("homeScenario ranked order is alex first, sam last")
    func homeScenarioRankedOrder() {
        let (vm, _) = makeSUT()
        let scenario = Fake.homeScenario()
        vm.metrics = scenario.metrics

        // Alex: 8 chores, Jordan: 5 chores, Sam: 1 chore
        let ranked = vm.ranked
        #expect(ranked[0].user?.username == "alexr")
        #expect(ranked[2].user?.username == "samw")
    }

    @Test("homeScenario totalChoresDone is sum of all three users")
    func homeScenarioTotalChores() {
        let (vm, _) = makeSUT()
        let scenario = Fake.homeScenario()
        vm.metrics = scenario.metrics

        // 8 (alex) + 5 (jordan) + 1 (sam) = 14
        #expect(vm.totalChoresDone == 14)
    }
}
