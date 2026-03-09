import Foundation
@testable import OneHome

// MARK: - Service Protocols
//
// These protocols mirror the public interface of each real service.
// The ViewModels currently use concrete singletons; these protocols allow
// testable ViewModels to accept injected mocks instead.
//
// Production code uses the concrete services directly via .shared.
// Tests wire in Mock* implementations via initializer injection on
// the testable ViewModel subclasses defined in each test file.

// MARK: PostServiceProtocol

protocol PostServiceProtocol {
    /// Fetch all published posts for a home, newest first
    func fetchFeed(for homeID: UUID) async throws -> [Post]
    /// Add a comment to a post, returns the saved comment with author populated
    func addComment(postID: UUID, userID: UUID, text: String) async throws -> Comment
    /// Create a draft post immediately (before user finishes editing)
    func createDraft(homeID: UUID, userID: UUID, category: PostCategory) async throws -> Post
    /// Publish a draft — sets is_draft = false
    func publish(postID: UUID) async throws
    /// Save draft text/image/category changes
    func updateDraft(_ post: Post) async throws
}

// MARK: HomeServiceProtocol

protocol HomeServiceProtocol {
    /// Fetch all homes the user belongs to
    func fetchHomes(for userID: UUID) async throws -> [Home]
    /// Create a new home with the given name, auto-generates invite code
    func createHome(name: String, ownerID: UUID) async throws -> Home
    /// Join a home using a short invite code
    func joinHomeByCode(_ code: String, userID: UUID) async throws -> Home
    /// Fetch all members of a home
    func fetchMembers(for homeID: UUID) async throws -> [User]
}

// MARK: StickyNoteServiceProtocol

protocol StickyNoteServiceProtocol {
    /// Post a sticky note — returns the saved note with author populated
    func post(text: String, homeID: UUID, userID: UUID) async throws -> StickyNote
    /// Fetch all non-expired sticky notes for a home
    func fetchActive(for homeID: UUID) async throws -> [StickyNote]
    /// Delete a sticky note by ID
    func delete(noteID: UUID) async throws
}

// MARK: MetricsServiceProtocol

protocol MetricsServiceProtocol {
    /// Fetch all user metrics for a home
    func fetchMetrics(for homeID: UUID) async throws -> [UserMetrics]
    /// Record a published post — updates chores_done, total_spent, or last_post_at
    func recordPost(userID: UUID, homeID: UUID, category: PostCategory, amount: Double) async throws
    /// Chore subcategory leaderboard
    func fetchChoreLeaderboard(homeID: UUID, subcategory: ChoreSubcategory, since: Date?) async throws -> [CategoryLeaderboardEntry]
    /// Overall chore leaderboard (all subcategories)
    func fetchOverallChoreLeaderboard(homeID: UUID, since: Date?) async throws -> [CategoryLeaderboardEntry]
    /// Spend leaderboard
    func fetchSpendLeaderboard(homeID: UUID, since: Date?) async throws -> [CategoryLeaderboardEntry]
}

// MARK: ReactionServiceProtocol

protocol ReactionServiceProtocol {
    /// Add an emoji reaction to a post, returns the saved reaction with user populated
    func addReaction(postID: UUID, userID: UUID, emoji: String) async throws -> Reaction
    /// Remove a reaction by its ID
    func removeReaction(id: UUID) async throws
    /// Fetch all reactions for a post
    func fetchReactions(for postID: UUID) async throws -> [Reaction]
}

// MARK: AuthServiceProtocol

protocol AuthServiceProtocol {
    /// Sign up a new user — creates auth + profile row
    func signUp(email: String, password: String, username: String, name: String) async throws -> User
    /// Sign in with email + password
    func signIn(email: String, password: String) async throws
    /// Sign out current session
    func signOut() async throws
    /// Return the currently authenticated user's profile, or nil
    func currentUser() async throws -> User?
}

// MARK: HouseholdReminderServiceProtocol

protocol HouseholdReminderServiceProtocol {
    /// Fetch all reminders for a home
    func fetchReminders(for homeID: UUID) async throws -> [HouseholdReminder]
    /// Create a new reminder
    func createReminder(homeID: UUID, userID: UUID, name: String, emoji: String, intervalDays: Int) async throws -> HouseholdReminder
    /// Clear a reminder (mark as just bought)
    func clearReminder(id: UUID, byUserID: UUID) async throws
    /// Delete a reminder
    func deleteReminder(id: UUID) async throws
}
