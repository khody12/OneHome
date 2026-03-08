import SwiftUI

@Observable
class MetricsViewModel {
    var metrics: [UserMetrics] = []
    var isLoading = false
    var currentUserMetrics: UserMetrics?

    func load(for home: Home, currentUserID: UUID? = nil) async {
#if DEBUG
        if home.id == DevPreview.home.id {
            metrics = DevPreview.metrics
            currentUserMetrics = metrics.first { $0.userID == currentUserID }
            return
        }
#endif
        isLoading = true
        metrics = (try? await MetricsService.shared.fetchMetrics(for: home.id)) ?? []
        if let uid = currentUserID {
            currentUserMetrics = metrics.first { $0.userID == uid }
        }
        isLoading = false
    }

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
}
