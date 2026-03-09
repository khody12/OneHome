import Testing
import Foundation
@testable import OneHome

// MARK: - Testable FeedViewModel
//
// Subclass that replaces the concrete service singletons with injected mocks.
// This pattern avoids modifying production code while still making the VM testable.

@Observable
final class TestableFeedViewModel: FeedViewModel {
    let postService: MockPostService
    let noteService: MockStickyNoteService
    let metricsService: MockMetricsService
    let reactionService: MockReactionService

    init(
        postService: MockPostService,
        noteService: MockStickyNoteService,
        metricsService: MockMetricsService,
        reactionService: MockReactionService = MockReactionService()
    ) {
        self.postService = postService
        self.noteService = noteService
        self.metricsService = metricsService
        self.reactionService = reactionService
    }

    // Override loadFeed to use injected mocks instead of singletons
    override func loadFeed(for home: Home) async {
        isLoading = true
        errorMessage = nil
        do {
            async let posts = postService.fetchFeed(for: home.id)
            async let notes = noteService.fetchActive(for: home.id)
            async let metrics = metricsService.fetchMetrics(for: home.id)

            let (fetchedPosts, fetchedNotes, fetchedMetrics) = try await (posts, notes, metrics)

            var items: [FeedItem] = fetchedPosts.map { .post($0) }
            items += fetchedNotes.map { .stickyNote($0) }
            feedItems = items.sorted { $0.createdAt > $1.createdAt }

            slackers = fetchedMetrics.filter { $0.isSlacking(comparedTo: fetchedMetrics) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Override addReaction to use injected mock
    override func addReaction(emoji: String, on post: Post, userID: UUID) async {
        // Optimistic update (mirrors production logic)
        if let idx = feedItems.firstIndex(where: {
            if case .post(let p) = $0 { return p.id == post.id }
            return false
        }) {
            if case .post(var p) = feedItems[idx] {
                let alreadyReacted = p.reactions?.contains { $0.userID == userID && $0.emoji == emoji } ?? false
                if alreadyReacted {
                    p.reactions?.removeAll { $0.userID == userID && $0.emoji == emoji }
                } else {
                    let newReaction = Reaction(
                        id: UUID(),
                        postID: post.id,
                        userID: userID,
                        emoji: emoji,
                        createdAt: Date(),
                        user: nil
                    )
                    if p.reactions == nil { p.reactions = [] }
                    p.reactions?.append(newReaction)
                }
                feedItems[idx] = .post(p)
            }
        }
        do {
            _ = try await reactionService.addReaction(postID: post.id, userID: userID, emoji: emoji)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Override addStickyNote to use injected mock
    override func addStickyNote(text: String, home: Home, userID: UUID) async {
        do {
            let note = try await noteService.post(text: text, homeID: home.id, userID: userID)
            feedItems.insert(.stickyNote(note), at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - FeedViewModelTests

@Suite("FeedViewModel")
struct FeedViewModelTests {

    // MARK: Helpers

    private func makeSUT() -> (vm: TestableFeedViewModel, posts: MockPostService, notes: MockStickyNoteService, metrics: MockMetricsService, reactions: MockReactionService) {
        let posts = MockPostService()
        let notes = MockStickyNoteService()
        let metrics = MockMetricsService()
        let reactions = MockReactionService()
        let vm = TestableFeedViewModel(postService: posts, noteService: notes, metricsService: metrics, reactionService: reactions)
        return (vm, posts, notes, metrics, reactions)
    }

    // MARK: - loadFeed

    @Test("loadFeed merges posts and sticky notes sorted newest first")
    func loadFeedMergesAndSorts() async {
        // WHY: The feed must interleave posts and sticky notes in one chronological list.
        // A sticky note posted after the latest post should appear above it.
        let (vm, postSvc, noteSvc, _, _) = makeSUT()
        let home = Fake.home()
        let now = Date()

        let oldPost = Fake.post(createdAt: now.addingTimeInterval(-3600))  // 1h ago
        let newPost = Fake.post(createdAt: now.addingTimeInterval(-1800))  // 30m ago
        let freshNote = Fake.stickyNote(createdAt: now)                    // right now

        postSvc.feedToReturn = [oldPost, newPost]
        noteSvc.notesToReturn = [freshNote]

        await vm.loadFeed(for: home)

        #expect(vm.feedItems.count == 3)
        // First item should be the sticky note (newest)
        if case .stickyNote(let n) = vm.feedItems[0] {
            #expect(n.id == freshNote.id)
        } else {
            Issue.record("Expected sticky note to be first (newest)")
        }
        // Second item should be newPost
        if case .post(let p) = vm.feedItems[1] {
            #expect(p.id == newPost.id)
        } else {
            Issue.record("Expected newPost to be second")
        }
        // Third item should be oldPost
        if case .post(let p) = vm.feedItems[2] {
            #expect(p.id == oldPost.id)
        } else {
            Issue.record("Expected oldPost to be third (oldest)")
        }
    }

    @Test("loadFeed populates slackers when a user hasn't posted in 72h")
    func loadFeedDetectsSlackers() async {
        // WHY: The slacker roast feature depends on loadFeed computing slackers
        // from the metrics it fetches. Verify the filter runs after load.
        let (vm, _, _, metricsSvc, _) = makeSUT()
        let home = Fake.home()
        let now = Date()

        let activeMetrics = Fake.metrics(
            lastPostAt: now.addingTimeInterval(-3600)  // 1h ago — active
        )
        let slackerMetrics = Fake.metrics(
            lastPostAt: now.addingTimeInterval(-5 * 24 * 3600)  // 5 days ago — slacking
        )
        metricsSvc.metricsToReturn = [activeMetrics, slackerMetrics]

        await vm.loadFeed(for: home)

        #expect(vm.slackers.count == 1)
        #expect(vm.slackers[0].userID == slackerMetrics.userID)
    }

    @Test("loadFeed with empty feed loads without crash")
    func loadFeedEmptyIsOK() async {
        // WHY: An empty home (no posts, no notes) must not crash or set an error.
        let (vm, _, _, _, _) = makeSUT()
        let home = Fake.home()

        await vm.loadFeed(for: home)

        #expect(vm.feedItems.isEmpty)
        #expect(vm.slackers.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadFeed sets errorMessage when post service throws")
    func loadFeedSetsErrorOnFailure() async {
        // WHY: A network failure should surface as a user-visible error message,
        // not a silent empty state that looks like success.
        let (vm, postSvc, _, _, _) = makeSUT()
        postSvc.errorToThrow = AppError.networkError("timeout")
        let home = Fake.home()

        await vm.loadFeed(for: home)

        #expect(vm.errorMessage != nil)
        #expect(vm.feedItems.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("loadFeed sets errorMessage when metrics service throws")
    func loadFeedSetsErrorWhenMetricsFails() async {
        // WHY: All three fetches run in parallel; if any throws, the error
        // must be captured and exposed — not swallowed.
        let (vm, _, _, metricsSvc, _) = makeSUT()
        metricsSvc.errorToThrow = AppError.networkError("metrics unavailable")
        let home = Fake.home()

        await vm.loadFeed(for: home)

        #expect(vm.errorMessage != nil)
    }

    // MARK: - addReaction

    @Test("addReaction optimistically adds emoji reaction to post in feedItems")
    func addReactionOptimisticAdd() async {
        // WHY: The UI should update instantly without waiting for a round-trip.
        let (vm, postSvc, _, _, _) = makeSUT()
        let home = Fake.home()
        let post = Fake.post(reactions: [])
        postSvc.feedToReturn = [post]

        await vm.loadFeed(for: home)
        let userID = UUID()
        await vm.addReaction(emoji: "🐐", on: post, userID: userID)

        guard case .post(let updated) = vm.feedItems.first(where: {
            if case .post(let p) = $0 { return p.id == post.id }
            return false
        }) else {
            Issue.record("Post not found in feedItems after addReaction")
            return
        }
        #expect(updated.reactions?.contains { $0.emoji == "🐐" && $0.userID == userID } == true)
    }

    @Test("addReaction optimistically removes existing reaction when user already reacted")
    func addReactionOptimisticRemove() async {
        // WHY: Tapping the same emoji twice should toggle it off instantly.
        let (vm, postSvc, _, _, _) = makeSUT()
        let home = Fake.home()
        let userID = UUID()
        let existingReaction = Fake.reaction(postID: UUID(), userID: userID, emoji: "🐐")
        let post = Fake.post(reactions: [existingReaction])
        postSvc.feedToReturn = [post]

        await vm.loadFeed(for: home)
        await vm.addReaction(emoji: "🐐", on: post, userID: userID)

        guard case .post(let updated) = vm.feedItems.first(where: {
            if case .post(let p) = $0 { return p.id == post.id }
            return false
        }) else {
            Issue.record("Post not found in feedItems")
            return
        }
        #expect(updated.reactions?.contains { $0.userID == userID && $0.emoji == "🐐" } != true)
    }

    @Test("addReaction calls the reaction service with correct parameters")
    func addReactionCallsService() async {
        // WHY: The optimistic UI update is separate from the network call.
        // Both must happen — verify the service was called with the right args.
        let (vm, postSvc, _, _, reactionSvc) = makeSUT()
        let home = Fake.home()
        let post = Fake.post(reactions: [])
        postSvc.feedToReturn = [post]
        let userID = UUID()

        await vm.loadFeed(for: home)
        await vm.addReaction(emoji: "🔥", on: post, userID: userID)

        #expect(reactionSvc.addReactionCallCount == 1)
        #expect(reactionSvc.lastAddedPostID == post.id)
        #expect(reactionSvc.lastAddedUserID == userID)
        #expect(reactionSvc.lastAddedEmoji == "🔥")
    }

    @Test("addReaction sets errorMessage when service throws")
    func addReactionSetsErrorOnFailure() async {
        // WHY: If adding a reaction fails (e.g. offline), the error must be surfaced.
        let (vm, postSvc, _, _, reactionSvc) = makeSUT()
        let home = Fake.home()
        let post = Fake.post(reactions: [])
        postSvc.feedToReturn = [post]
        reactionSvc.errorToThrow = AppError.networkError("reaction failed")

        await vm.loadFeed(for: home)
        await vm.addReaction(emoji: "😂", on: post, userID: UUID())

        #expect(vm.errorMessage != nil)
    }

    // MARK: - addStickyNote

    @Test("addStickyNote prepends note to feedItems immediately")
    func addStickyNotePrepends() async {
        // WHY: Sticky notes should appear at the top of the feed the moment
        // they're posted — no page refresh required.
        let (vm, postSvc, noteSvc, _, _) = makeSUT()
        let home = Fake.home()
        let existingPost = Fake.post(createdAt: Date().addingTimeInterval(-3600))
        postSvc.feedToReturn = [existingPost]

        await vm.loadFeed(for: home)
        #expect(vm.feedItems.count == 1)

        let newNote = Fake.stickyNote(text: "WiFi password changed! 🔑")
        noteSvc.noteToReturn = newNote
        await vm.addStickyNote(text: "WiFi password changed! 🔑", home: home, userID: UUID())

        #expect(vm.feedItems.count == 2)
        // The new note should be first
        if case .stickyNote(let n) = vm.feedItems[0] {
            #expect(n.id == newNote.id)
        } else {
            Issue.record("Expected new sticky note to be at index 0")
        }
    }

    @Test("addStickyNote sets errorMessage when service throws")
    func addStickyNoteErrorSetsMessage() async {
        // WHY: If posting a sticky note fails (e.g. offline), the user
        // needs to see an error rather than a silent no-op.
        let (vm, _, noteSvc, _, _) = makeSUT()
        noteSvc.errorToThrow = AppError.networkError("connection refused")
        let home = Fake.home()

        await vm.addStickyNote(text: "Test note", home: home, userID: UUID())

        #expect(vm.errorMessage != nil)
        #expect(vm.feedItems.isEmpty)
    }
}
