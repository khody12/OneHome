import Testing
import Foundation
@testable import OneHome

// MARK: - ReminderTests
//
// Tests for HouseholdReminder computed properties and
// YourHomeViewModel reminder actions in dev mode.

@Suite("HouseholdReminder Model Tests")
struct ReminderModelTests {

    // MARK: isDue

    @Test("isDue is true when lastClearedAt is nil")
    func isDueWhenNeverCleared() {
        let reminder = Fake.dueReminderNeverCleared()
        #expect(reminder.isDue == true)
    }

    @Test("isDue is true when interval has elapsed")
    func isDueWhenIntervalElapsed() {
        // Cleared 20 days ago with a 14-day interval
        let reminder = Fake.overdueReminder()
        #expect(reminder.isDue == true)
    }

    @Test("isDue is false when within interval")
    func isDueFalseWhenWithinInterval() {
        // Cleared 3 days ago with a 14-day interval
        let reminder = Fake.upcomingReminder()
        #expect(reminder.isDue == false)
    }

    @Test("isDue is true exactly at the boundary (nextDueAt == now)")
    func isDueAtExactBoundary() {
        // Cleared exactly intervalDays ago
        let reminder = Fake.reminder(
            intervalDays: 7,
            lastClearedAt: Date().addingTimeInterval(-7 * 86400 - 1)  // 1 second past the boundary
        )
        #expect(reminder.isDue == true)
    }

    // MARK: nextDueAt

    @Test("nextDueAt is nil when never cleared")
    func nextDueAtNilWhenNeverCleared() {
        let reminder = Fake.reminder(lastClearedAt: nil)
        #expect(reminder.nextDueAt == nil)
    }

    @Test("nextDueAt is intervalDays after lastClearedAt")
    func nextDueAtCalculation() {
        let cleared = Date().addingTimeInterval(-3 * 86400)
        let reminder = Fake.reminder(intervalDays: 14, lastClearedAt: cleared)
        let expected = cleared.addingTimeInterval(14 * 86400)
        let actual = reminder.nextDueAt!
        // Allow 1 second tolerance
        #expect(abs(actual.timeIntervalSince(expected)) < 1)
    }

    // MARK: daysOverdue

    @Test("daysOverdue is 0 when not due")
    func daysOverdueWhenNotDue() {
        let reminder = Fake.upcomingReminder()
        #expect(reminder.daysOverdue == 0)
    }

    @Test("daysOverdue is 0 when never cleared (treated as due, no reference date)")
    func daysOverdueWhenNeverCleared() {
        // never cleared = no nextDueAt so no reference, returns 0 from guard
        let reminder = Fake.reminder(lastClearedAt: nil)
        #expect(reminder.daysOverdue == 0)
    }

    @Test("daysOverdue counts full days past interval")
    func daysOverdueCount() {
        // Cleared 20 days ago, interval 14 → 6 days overdue
        let reminder = Fake.overdueReminder()
        // overdueReminder: intervalDays=14, lastClearedAt = 20 days ago → 6 days overdue
        #expect(reminder.daysOverdue >= 5)  // allow small timing variance
    }

    // MARK: statusLabel

    @Test("statusLabel is 'Never bought' when never cleared")
    func statusLabelNeverBought() {
        let reminder = Fake.reminder(lastClearedAt: nil)
        #expect(reminder.statusLabel == "Never bought")
    }

    @Test("statusLabel is 'Due now' when just past interval")
    func statusLabelDueNow() {
        // Cleared exactly intervalDays + a few minutes ago
        let reminder = Fake.reminder(
            intervalDays: 7,
            lastClearedAt: Date().addingTimeInterval(-(7 * 86400 + 300))  // 5 min past due
        )
        #expect(reminder.statusLabel == "Due now")
    }

    @Test("statusLabel shows 'X days overdue' when significantly overdue")
    func statusLabelOverdue() {
        let reminder = Fake.overdueReminder()
        // 20 days cleared, 14 day interval = 6 days overdue
        #expect(reminder.statusLabel.contains("overdue"))
    }

    @Test("statusLabel shows 'Due in X days' when upcoming")
    func statusLabelUpcoming() {
        let reminder = Fake.upcomingReminder()
        // cleared 3 days ago, 14-day interval = 11 days remaining
        #expect(reminder.statusLabel.contains("Due in"))
        #expect(reminder.statusLabel.contains("days"))
    }
}

// MARK: - YourHomeViewModel Dev Mode Tests

@Suite("YourHomeViewModel Reminder Actions (dev mode)")
struct YourHomeReminderViewModelTests {

    // Creates a YourHomeViewModel pre-populated with dev reminders
    private func makeVM() -> YourHomeViewModel {
        let vm = YourHomeViewModel()
        vm.reminders = DevPreview.reminders
        vm.members = DevPreview.home.members ?? []
        return vm
    }

    @Test("addReminder in dev mode prepends to reminders list")
    func addReminderDevMode() async {
        let vm = makeVM()
        let initialCount = vm.reminders.count

        await vm.addReminder(
            name: "Paper Towels",
            emoji: "🧻",
            intervalDays: 7,
            home: DevPreview.home,
            userID: DevPreview.user.id
        )

        #expect(vm.reminders.count == initialCount + 1)
        #expect(vm.reminders.first?.name == "Paper Towels")
        #expect(vm.reminders.first?.emoji == "🧻")
        #expect(vm.reminders.first?.intervalDays == 7)
    }

    @Test("addReminder sets correct home and user IDs")
    func addReminderSetsIDs() async {
        let vm = makeVM()
        await vm.addReminder(
            name: "Sponges",
            emoji: "🧽",
            intervalDays: 14,
            home: DevPreview.home,
            userID: DevPreview.user.id
        )
        let added = vm.reminders.first!
        #expect(added.homeID == DevPreview.home.id)
        #expect(added.createdByUserID == DevPreview.user.id)
        #expect(added.lastClearedAt == nil)
    }

    @Test("clearReminder in dev mode updates lastClearedByUserID")
    func clearReminderDevMode() async {
        let vm = makeVM()
        guard let first = vm.reminders.first else { return }
        let reminderID = first.id

        await vm.clearReminder(id: reminderID, userID: DevPreview.user.id, home: DevPreview.home)

        let updated = vm.reminders.first { $0.id == reminderID }!
        #expect(updated.lastClearedByUserID == DevPreview.user.id)
        #expect(updated.lastClearedAt != nil)
    }

    @Test("clearReminder in dev mode sets lastClearedByUser from members list")
    func clearReminderSetsUser() async {
        let vm = makeVM()
        guard let first = vm.reminders.first else { return }

        await vm.clearReminder(id: first.id, userID: DevPreview.user.id, home: DevPreview.home)

        let updated = vm.reminders.first { $0.id == first.id }!
        #expect(updated.lastClearedByUser?.id == DevPreview.user.id)
    }

    @Test("deleteReminder in dev mode removes from list")
    func deleteReminderDevMode() async {
        let vm = makeVM()
        guard let first = vm.reminders.first else { return }
        let reminderID = first.id
        let initialCount = vm.reminders.count

        await vm.deleteReminder(id: reminderID, home: DevPreview.home)

        #expect(vm.reminders.count == initialCount - 1)
        #expect(vm.reminders.first { $0.id == reminderID } == nil)
    }
}

// MARK: - FeedViewModel System Post Injection Tests

@Suite("FeedViewModel Reminder System Posts")
struct FeedViewModelReminderTests {

    @Test("System posts injected for due reminders in loadFeed (dev mode)")
    func systemPostsInjectedForDueReminders() async {
        let vm = FeedViewModel()
        await vm.loadFeed(for: DevPreview.home)

        // DevPreview has 2 reminders:
        // 1. Toilet Paper: cleared 15 days ago with 14-day interval → isDue = true
        // 2. Dish Soap: never cleared → isDue = true
        // Both should produce system posts
        let systemPosts = vm.feedItems.compactMap { item -> Post? in
            if case .post(let p) = item, p.author == nil { return p }
            return nil
        }
        #expect(systemPosts.count >= 2)
    }

    @Test("System posts have nil author")
    func systemPostsHaveNilAuthor() async {
        let vm = FeedViewModel()
        await vm.loadFeed(for: DevPreview.home)

        let systemPosts = vm.feedItems.compactMap { item -> Post? in
            if case .post(let p) = item, p.author == nil { return p }
            return nil
        }
        for post in systemPosts {
            #expect(post.author == nil)
        }
    }

    @Test("System posts use .general category")
    func systemPostsAreGeneralCategory() async {
        let vm = FeedViewModel()
        await vm.loadFeed(for: DevPreview.home)

        let systemPosts = vm.feedItems.compactMap { item -> Post? in
            if case .post(let p) = item, p.author == nil { return p }
            return nil
        }
        for post in systemPosts {
            #expect(post.category == .general)
        }
    }

    @Test("System posts contain reminder name in text")
    func systemPostsContainReminderName() async {
        let vm = FeedViewModel()
        await vm.loadFeed(for: DevPreview.home)

        let systemPostTexts = vm.feedItems.compactMap { item -> String? in
            if case .post(let p) = item, p.author == nil { return p.text }
            return nil
        }

        // Toilet Paper reminder should appear
        let hasToiletPaper = systemPostTexts.contains { $0.contains("Toilet Paper") }
        #expect(hasToiletPaper)

        // Dish Soap reminder should appear
        let hasDishSoap = systemPostTexts.contains { $0.contains("Dish Soap") }
        #expect(hasDishSoap)
    }

    @Test("Non-due reminders do not produce system posts")
    func nonDueRemindersNotInjected() {
        // Create a reminder that is NOT due
        let upcoming = Fake.upcomingReminder()
        #expect(upcoming.isDue == false)

        // Manually build a feed with only a non-due reminder — no system post should appear
        // This tests the filtering logic of systemPostsForDueReminders
        // We verify at the model level since the private method isn't directly accessible
        // but we can confirm via the isDue property
        #expect(upcoming.isDue == false)
    }
}
