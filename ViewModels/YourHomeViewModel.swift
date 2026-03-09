import Foundation
import Observation

@Observable
class YourHomeViewModel {
    var subscriptions: [Subscription] = []
    var spendLogs: [SpendLog] = []
    var members: [User] = []
    var reminders: [HouseholdReminder] = []
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
            reminders = DevPreview.reminders
            isLoading = false
            return
        }
#endif

        do {
            async let fetchedSubs = SubscriptionService.shared.fetchSubscriptions(for: home.id)
            async let fetchedLogs = SpendLogService.shared.fetchLogs(for: home.id)
            async let fetchedMembers = HomeService.shared.fetchMembers(for: home.id)
            async let fetchedReminders = HouseholdReminderService.shared.fetchReminders(for: home.id)

            let (subs, logs, mems, rems) = try await (fetchedSubs, fetchedLogs, fetchedMembers, fetchedReminders)
            subscriptions = subs
            spendLogs = logs
            members = mems
            reminders = rems
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
#if DEBUG
        if home.id == DevPreview.home.id {
            let author = members.first { $0.id == userID } ?? DevPreview.user
            let newLog = SpendLog(
                id: UUID(), homeID: home.id, userID: userID,
                amount: logAmount, category: logCategory,
                note: logNote, createdAt: Date(), user: author
            )
            spendLogs.insert(newLog, at: 0)
            logAmount = 0; logNote = ""; logCategory = .household
            return
        }
#endif
        do {
            let newLog = try await SpendLogService.shared.logSpend(
                homeID: home.id,
                userID: userID,
                amount: logAmount,
                category: logCategory,
                note: logNote
            )
            spendLogs.insert(newLog, at: 0)
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

    // MARK: - Reminder Actions

    func addReminder(name: String, emoji: String, intervalDays: Int, home: Home, userID: UUID) async {
#if DEBUG
        if home.id == DevPreview.home.id {
            let newReminder = HouseholdReminder(
                id: UUID(),
                homeID: home.id,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays,
                lastClearedAt: nil,
                lastClearedByUserID: nil,
                lastClearedByUser: nil,
                createdAt: Date(),
                createdByUserID: userID
            )
            reminders.insert(newReminder, at: 0)
            return
        }
#endif
        do {
            let newReminder = try await HouseholdReminderService.shared.createReminder(
                homeID: home.id,
                userID: userID,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays
            )
            reminders.insert(newReminder, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearReminder(id: UUID, userID: UUID, home: Home) async {
#if DEBUG
        if home.id == DevPreview.home.id {
            guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
            reminders[idx].lastClearedAt = Date()
            reminders[idx].lastClearedByUserID = userID
            reminders[idx].lastClearedByUser = members.first { $0.id == userID } ?? DevPreview.user
            return
        }
#endif
        do {
            try await HouseholdReminderService.shared.clearReminder(id: id, byUserID: userID)
            guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
            reminders[idx].lastClearedAt = Date()
            reminders[idx].lastClearedByUserID = userID
            reminders[idx].lastClearedByUser = members.first { $0.id == userID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReminder(id: UUID, home: Home) async {
#if DEBUG
        if home.id == DevPreview.home.id {
            reminders.removeAll { $0.id == id }
            return
        }
#endif
        do {
            try await HouseholdReminderService.shared.deleteReminder(id: id)
            reminders.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
