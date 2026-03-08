import Foundation
import Observation

@Observable
class YourHomeViewModel {
    var subscriptions: [Subscription] = []
    var spendLogs: [SpendLog] = []
    var members: [User] = []
    var isLoading = false
    var errorMessage: String?

    // Spend log form state
    var logAmount: Double = 0
    var logNote: String = ""
    var logCategory: SpendCategory = .household

    func load(home: Home) async {
        isLoading = true
        errorMessage = nil

#if DEBUG
        if home.id == DevPreview.home.id {
            subscriptions = DevPreview.subscriptions
            spendLogs = DevPreview.spendLogs
            members = home.members ?? []
            isLoading = false
            return
        }
#endif

        do {
            async let fetchedSubs = SubscriptionService.shared.fetchSubscriptions(for: home.id)
            async let fetchedLogs = SpendLogService.shared.fetchLogs(for: home.id)
            async let fetchedMembers = HomeService.shared.fetchMembers(for: home.id)

            let (subs, logs, mems) = try await (fetchedSubs, fetchedLogs, fetchedMembers)
            subscriptions = subs
            spendLogs = logs
            members = mems
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Computed spend totals

    var totalByCategory: [SpendCategory: Double] {
        SpendLogService.shared.totalByCategory(logs: spendLogs)
    }

    var totalByUser: [UUID: Double] {
        SpendLogService.shared.totalByUser(logs: spendLogs)
    }

    var grandTotal: Double {
        spendLogs.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Actions

    func logSpend(home: Home, userID: UUID) async {
        guard logAmount > 0 else { return }
        do {
            let newLog = try await SpendLogService.shared.logSpend(
                homeID: home.id,
                userID: userID,
                amount: logAmount,
                category: logCategory,
                note: logNote
            )
            spendLogs.insert(newLog, at: 0)
            // Reset form
            logAmount = 0
            logNote = ""
            logCategory = .household
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSubscription(_ sub: Subscription, memberIDs: [UUID]) async {
        do {
            let created = try await SubscriptionService.shared.createSubscription(sub, memberIDs: memberIDs)
            subscriptions.insert(created, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSubscription(_ sub: Subscription) async {
        do {
            try await SubscriptionService.shared.deleteSubscription(id: sub.id)
            subscriptions.removeAll { $0.id == sub.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
