import SwiftUI

// MARK: - LeaderboardType

enum LeaderboardType: String, CaseIterable, Identifiable {
    case overall = "Overall"
    case chores = "Chores"
    case spending = "Spending"
    var id: String { rawValue }
}

// MARK: - TimeRange

enum TimeRange: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case thisMonth = "This Month"
    var id: String { rawValue }

    /// nil means all-time; non-nil is the first moment of the current calendar month.
    var since: Date? {
        switch self {
        case .allTime: return nil
        case .thisMonth:
            return Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: Date())
            )
        }
    }
}

// MARK: - MetricsViewModel

@Observable
class MetricsViewModel {
    var metrics: [UserMetrics] = []
    var isLoading = false
    var currentUserMetrics: UserMetrics?

    // MARK: Leaderboard state

    var selectedLeaderboard: LeaderboardType = .overall
    var selectedTimeRange: TimeRange = .allTime
    var selectedChoreSubcategory: ChoreSubcategory? = nil  // nil = all chores

    var choreLeaderboards: [ChoreSubcategory: [CategoryLeaderboardEntry]] = [:]
    var overallChoreLeaderboard: [CategoryLeaderboardEntry] = []
    var spendLeaderboard: [CategoryLeaderboardEntry] = []

    func load(for home: Home, currentUserID: UUID? = nil) async {
#if DEBUG
        if home.id == DevPreview.home.id {
            metrics = DevPreview.metrics
            currentUserMetrics = metrics.first { $0.userID == currentUserID }
            // Compute leaderboards from DevPreview data
            computeDevLeaderboards()
            return
        }
#endif
        isLoading = true
        metrics = (try? await MetricsService.shared.fetchMetrics(for: home.id)) ?? []
        if let uid = currentUserID {
            currentUserMetrics = metrics.first { $0.userID == uid }
        }

        let since = selectedTimeRange.since

        // Load all leaderboards in parallel
        async let overallResult = MetricsService.shared.fetchOverallChoreLeaderboard(homeID: home.id, since: since)
        async let spendResult = MetricsService.shared.fetchSpendLeaderboard(homeID: home.id, since: since)

        overallChoreLeaderboard = (try? await overallResult) ?? []
        spendLeaderboard = (try? await spendResult) ?? []

        // Load per-subcategory leaderboards in parallel
        await withTaskGroup(of: (ChoreSubcategory, [CategoryLeaderboardEntry]).self) { group in
            for sub in ChoreSubcategory.allCases {
                group.addTask {
                    let entries = (try? await MetricsService.shared.fetchChoreLeaderboard(homeID: home.id, subcategory: sub, since: since)) ?? []
                    return (sub, entries)
                }
            }
            for await (sub, entries) in group {
                choreLeaderboards[sub] = entries
            }
        }

        isLoading = false
    }

    // MARK: - Dev leaderboard computation

#if DEBUG
    private func computeDevLeaderboards() {
        let posts = DevPreview.posts.filter { !$0.isDraft }
        let spendLogs = DevPreview.spendLogs

        // Overall chore leaderboard
        let chorePosts = posts.filter { $0.category == .chore }
        overallChoreLeaderboard = buildChoreLeaderboard(from: chorePosts)

        // Per-subcategory chore leaderboards
        for sub in ChoreSubcategory.allCases {
            let filtered = chorePosts.filter { $0.choreSubcategory == sub || (sub == .other && $0.choreSubcategory == nil) }
            choreLeaderboards[sub] = buildChoreLeaderboard(from: filtered)
        }

        // Spend leaderboard from spendLogs
        var amountMap: [UUID: (user: User, total: Double)] = [:]
        for log in spendLogs {
            if let user = log.user {
                if var existing = amountMap[log.userID] {
                    existing.total += log.amount
                    amountMap[log.userID] = existing
                } else {
                    amountMap[log.userID] = (user: user, total: log.amount)
                }
            }
        }
        spendLeaderboard = amountMap.map { id, val in
            CategoryLeaderboardEntry(id: id, user: val.user, count: 0, totalAmount: val.total)
        }.sorted { $0.totalAmount > $1.totalAmount }
    }

    private func buildChoreLeaderboard(from posts: [Post]) -> [CategoryLeaderboardEntry] {
        var countMap: [UUID: (user: User, count: Int)] = [:]
        for post in posts {
            if let author = post.author {
                if var existing = countMap[post.userID] {
                    existing.count += 1
                    countMap[post.userID] = existing
                } else {
                    countMap[post.userID] = (user: author, count: 1)
                }
            }
        }
        return countMap.map { id, val in
            CategoryLeaderboardEntry(id: id, user: val.user, count: val.count, totalAmount: 0)
        }.sorted { $0.count > $1.count }
    }
#endif

    // MARK: - Existing computed properties

    // Sort by chores done descending
    var ranked: [UserMetrics] {
        metrics.sorted { $0.choresDone > $1.choresDone }
    }

    // Users who are slacking relative to the group
    var slackers: [UserMetrics] {
        metrics.filter { $0.isSlacking(comparedTo: metrics) }
    }

    // Total chores across all roommates
    var totalChoresDone: Int {
        metrics.reduce(0) { $0 + $1.choresDone }
    }

    // Total money spent across all roommates
    var totalSpent: Double {
        metrics.reduce(0) { $0 + $1.totalSpent }
    }

    // 1-indexed rank for the given user by choresDone (descending)
    func currentUserRank(userID: UUID) -> Int {
        let sorted = ranked
        return (sorted.firstIndex { $0.userID == userID } ?? 0) + 1
    }

    // MARK: - Active leaderboard entries

    /// The currently-displayed leaderboard entries based on selectedLeaderboard + selectedChoreSubcategory.
    var activeLeaderboardEntries: [CategoryLeaderboardEntry] {
        switch selectedLeaderboard {
        case .overall:
            return overallChoreLeaderboard
        case .chores:
            if let sub = selectedChoreSubcategory {
                return choreLeaderboards[sub] ?? []
            }
            return overallChoreLeaderboard
        case .spending:
            return spendLeaderboard
        }
    }
}
