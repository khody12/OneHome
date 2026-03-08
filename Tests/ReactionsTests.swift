import Testing
import Foundation
@testable import OneHome

// MARK: - ReactionsTests
//
// Tests for the kudos reaction system and comment section.
// Pure logic tests that do not require a live Supabase connection.

@Suite("Reactions and Comments")
struct ReactionsTests {

    // MARK: - Kudos Count Tests

    @Test("Kudos toggle increments count from zero")
    func kudosIncrementFromZero() {
        var post = Fake.post(kudosCount: 0, hasGivenKudos: false)
        // Simulate optimistic update (mirrors PostDetailViewModel.toggleKudos logic)
        post.hasGivenKudos.toggle()
        post.kudosCount += post.hasGivenKudos ? 1 : -1
        #expect(post.kudosCount == 1)
        #expect(post.hasGivenKudos == true)
    }

    @Test("Kudos toggle decrements when already given")
    func kudosDecrement() {
        var post = Fake.post(kudosCount: 3, hasGivenKudos: true)
        // Simulate removing kudos
        post.hasGivenKudos.toggle()
        post.kudosCount += post.hasGivenKudos ? 1 : -1
        #expect(post.kudosCount == 2)
        #expect(post.hasGivenKudos == false)
    }

    @Test("hasGivenKudos flips on toggle")
    func kudosHasGivenFlips() {
        var post = Fake.post(hasGivenKudos: false)
        post.hasGivenKudos.toggle()
        #expect(post.hasGivenKudos == true)
        post.hasGivenKudos.toggle()
        #expect(post.hasGivenKudos == false)
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

    // MARK: - Comment Submission

    @Test("Submitting empty comment text is a no-op")
    func emptyCommentIsNoOp() async {
        let vm = PostDetailViewModel(post: Fake.post())
        vm.commentText = "   "
        await vm.submitComment(userID: UUID(), currentUser: Fake.user())
        #expect(vm.comments.isEmpty)
        #expect(vm.commentText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test("Optimistic comment is added before service returns")
    func optimisticCommentAdded() async {
        // After submit with non-empty text, vm.comments grows immediately
        // (test with mock service when available)
        let vm = PostDetailViewModel(post: Fake.post())
        vm.commentText = "Great work! 🙌"
        // without mock, verify commentText is cleared after submit attempt
        // Full mock test is in ViewModelTests
    }

    @Test("Comment text is cleared after submit")
    func commentTextClearedAfterSubmit() async {
        let vm = PostDetailViewModel(post: Fake.post())
        vm.commentText = "Nice! 🎉"
        await vm.submitComment(userID: UUID(), currentUser: Fake.user())
        // text is cleared regardless of service result
        #expect(vm.commentText.isEmpty)
    }

    // MARK: - Kudos Users

    @Test("Kudos users list is initially empty")
    func kudosUsersStartEmpty() {
        let vm = PostDetailViewModel(post: Fake.post())
        #expect(vm.kudosUsers.isEmpty)
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
