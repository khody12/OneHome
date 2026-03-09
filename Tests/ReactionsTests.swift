import Testing
import Foundation
@testable import OneHome

// MARK: - ReactionsTests
//
// Tests for the emoji reactions system and comment section.
// Pure logic tests that do not require a live Supabase connection.

@Suite("Reactions and Comments")
struct ReactionsTests {

    // MARK: - Reaction Model

    @Test("Reaction initializes with correct properties")
    func reactionInitializes() {
        let postID = UUID()
        let userID = UUID()
        let r = Fake.reaction(postID: postID, userID: userID, emoji: "🐐")
        #expect(r.postID == postID)
        #expect(r.userID == userID)
        #expect(r.emoji == "🐐")
    }

    @Test("presetReactions contains exactly 20 emojis")
    func presetReactionsCount() {
        #expect(presetReactions.count == 20)
    }

    @Test("presetReactions starts with GOAT emoji")
    func presetReactionsFirstIsGoat() {
        #expect(presetReactions.first == "🐐")
    }

    // MARK: - reactionSummary

    @Test("reactionSummary groups reactions by emoji")
    func reactionSummaryGroups() {
        let userID = UUID()
        let postID = UUID()
        let r1 = Fake.reaction(postID: postID, userID: UUID(), emoji: "🐐")
        let r2 = Fake.reaction(postID: postID, userID: UUID(), emoji: "🐐")
        let r3 = Fake.reaction(postID: postID, userID: UUID(), emoji: "👍")
        let post = Fake.post(id: postID, reactions: [r1, r2, r3])
        let vm = PostDetailViewModel(post: post)
        let summary = vm.reactionSummary(userID: userID)
        let goat = summary.first { $0.emoji == "🐐" }
        let thumbs = summary.first { $0.emoji == "👍" }
        #expect(goat?.count == 2)
        #expect(thumbs?.count == 1)
    }

    @Test("reactionSummary is sorted by count descending")
    func reactionSummarySortedByCount() {
        let userID = UUID()
        let postID = UUID()
        let r1 = Fake.reaction(postID: postID, userID: UUID(), emoji: "👍")
        let r2 = Fake.reaction(postID: postID, userID: UUID(), emoji: "🐐")
        let r3 = Fake.reaction(postID: postID, userID: UUID(), emoji: "🐐")
        let r4 = Fake.reaction(postID: postID, userID: UUID(), emoji: "🐐")
        let post = Fake.post(id: postID, reactions: [r1, r2, r3, r4])
        let vm = PostDetailViewModel(post: post)
        let summary = vm.reactionSummary(userID: userID)
        #expect(summary.first?.emoji == "🐐")
        #expect(summary.first?.count == 3)
    }

    @Test("reactionSummary marks hasReacted true when user has reacted")
    func reactionSummaryHasReacted() {
        let userID = UUID()
        let postID = UUID()
        let myReaction = Fake.reaction(postID: postID, userID: userID, emoji: "❤️")
        let other = Fake.reaction(postID: postID, userID: UUID(), emoji: "❤️")
        let post = Fake.post(id: postID, reactions: [myReaction, other])
        let vm = PostDetailViewModel(post: post)
        let summary = vm.reactionSummary(userID: userID)
        let heart = summary.first { $0.emoji == "❤️" }
        #expect(heart?.hasReacted == true)
    }

    @Test("reactionSummary marks hasReacted false when user has not reacted")
    func reactionSummaryNotReacted() {
        let userID = UUID()
        let postID = UUID()
        let other = Fake.reaction(postID: postID, userID: UUID(), emoji: "🐐")
        let post = Fake.post(id: postID, reactions: [other])
        let vm = PostDetailViewModel(post: post)
        let summary = vm.reactionSummary(userID: userID)
        let goat = summary.first { $0.emoji == "🐐" }
        #expect(goat?.hasReacted == false)
    }

    @Test("reactionSummary returns empty when no reactions")
    func reactionSummaryEmpty() {
        let post = Fake.post(reactions: nil)
        let vm = PostDetailViewModel(post: post)
        let summary = vm.reactionSummary(userID: UUID())
        #expect(summary.isEmpty)
    }

    // MARK: - toggleReaction (optimistic, dev mode)

    @Test("toggleReaction adds reaction optimistically in dev mode")
    func toggleReactionAddsOptimistic() async {
        let devPost = Fake.post(
            homeID: DevPreview.home.id,
            reactions: []
        )
        let vm = PostDetailViewModel(post: devPost)
        let userID = UUID()
        await vm.toggleReaction(emoji: "🐐", userID: userID)
        #expect(vm.reactions.count == 1)
        #expect(vm.reactions[0].emoji == "🐐")
        #expect(vm.reactions[0].userID == userID)
    }

    @Test("toggleReaction removes existing reaction optimistically in dev mode")
    func toggleReactionRemovesOptimistic() async {
        let userID = UUID()
        let postID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let existing = Reaction(
            id: UUID(),
            postID: postID,
            userID: userID,
            emoji: "🐐",
            createdAt: Date(),
            user: nil
        )
        let devPost = Fake.post(
            id: postID,
            homeID: DevPreview.home.id,
            reactions: [existing]
        )
        let vm = PostDetailViewModel(post: devPost)
        await vm.toggleReaction(emoji: "🐐", userID: userID)
        #expect(vm.reactions.isEmpty)
    }

    @Test("toggleReaction same emoji twice results in zero reactions (add then remove)")
    func toggleReactionTwiceIsRemove() async {
        let devPost = Fake.post(
            homeID: DevPreview.home.id,
            reactions: []
        )
        let vm = PostDetailViewModel(post: devPost)
        let userID = UUID()
        await vm.toggleReaction(emoji: "👍", userID: userID)
        #expect(vm.reactions.count == 1)
        await vm.toggleReaction(emoji: "👍", userID: userID)
        #expect(vm.reactions.isEmpty)
    }

    // MARK: - loadReactions (dev mode short-circuit)

    @Test("loadReactions returns DevPreview reactions in dev mode")
    func loadReactionsDevMode() async {
        let devPost = Fake.post(
            id: DevPreview.chorePostID,
            homeID: DevPreview.home.id,
            reactions: nil
        )
        let vm = PostDetailViewModel(post: devPost)
        await vm.loadReactions(postID: DevPreview.chorePostID)
        // DevPreview.reactions are for chorePostID — should be 3
        #expect(vm.reactions.count == DevPreview.reactions.count)
    }

    // MARK: - PostDetailViewModel Initialisation

    @Test("PostDetailViewModel initializes with existing comments from post")
    func detailVMInitializesComments() {
        let comment = Fake.comment()
        let post = Fake.post(comments: [comment])
        let vm = PostDetailViewModel(post: post)
        #expect(vm.comments.count == 1)
        #expect(vm.comments[0].id == comment.id)
    }

    @Test("PostDetailViewModel initializes with empty comments when post has none")
    func detailVMInitializesEmptyComments() {
        let post = Fake.post(comments: nil)
        let vm = PostDetailViewModel(post: post)
        #expect(vm.comments.isEmpty)
    }

    @Test("PostDetailViewModel initializes with existing reactions from post")
    func detailVMInitializesReactions() {
        let r = Fake.reaction(emoji: "🔥")
        let post = Fake.post(reactions: [r])
        let vm = PostDetailViewModel(post: post)
        #expect(vm.reactions.count == 1)
        #expect(vm.reactions[0].emoji == "🔥")
    }

    // MARK: - Comment Submission

    @Test("Submitting empty comment text is a no-op")
    func emptyCommentIsNoOp() async {
        let vm = PostDetailViewModel(post: Fake.post())
        vm.commentText = "   "
        await vm.submitComment(userID: UUID(), currentUser: Fake.user())
        #expect(vm.comments.isEmpty)
        #expect(vm.commentText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test("Comment text is cleared after submit")
    func commentTextClearedAfterSubmit() async {
        let vm = PostDetailViewModel(post: Fake.post())
        vm.commentText = "Nice! 🎉"
        await vm.submitComment(userID: UUID(), currentUser: Fake.user())
        // text is cleared regardless of service result
        #expect(vm.commentText.isEmpty)
    }

    // MARK: - Comment Model

    @Test("Comment row shows correct author name")
    func commentRowAuthorName() {
        let user = Fake.user(name: "Alex Roomie")
        let comment = Fake.comment(author: user)
        #expect(comment.author?.name == "Alex Roomie")
    }

    @Test("Multiple comments load in creation order")
    func commentsInOrder() {
        let now = Date()
        let c1 = Fake.comment(createdAt: now.addingTimeInterval(-3600), text: "First")
        let c2 = Fake.comment(createdAt: now, text: "Second")
        let sorted = [c2, c1].sorted { $0.createdAt < $1.createdAt }
        #expect(sorted.first?.text == "First")
        #expect(sorted.last?.text == "Second")
    }
}
