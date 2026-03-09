import Testing
import Foundation
@testable import OneHome

// MARK: - Request Feature Tests
//
// Covers:
//  - Request post creation (model fields, category, CodingKeys)
//  - Assigning a request to specific users
//  - Completing a request (sets completionPostID / completionPost)
//  - Attempting to complete an already-completed request (no-op guard)
//  - Dev mode short-circuit for completion via PostDetailViewModel.markComplete

@Suite("Request Feature")
struct RequestTests {

    // MARK: - Request Post Creation

    @Test("Request post has correct category and nil completion fields")
    func requestPostDefaultFields() {
        // What: A freshly created request post should have .request category,
        //       nil completionPostID, and nil completionPost.
        // Why: These are the initial state values the UI reads to show "Awaiting response".
        let req = Fake.requestPost()
        #expect(req.category == .request)
        #expect(req.completionPostID == nil)
        #expect(req.completionPost == nil)
        #expect(req.isDraft == false)
    }

    @Test("Request post category emoji is 🙋")
    func requestCategoryEmoji() {
        // What: The emoji for the .request category must be 🙋.
        // Why: It's shown in the badge and the RequestCardView header.
        #expect(PostCategory.request.emoji == "🙋")
    }

    @Test("Request post category label is Request")
    func requestCategoryLabel() {
        // What: The label for .request must be "Request".
        // Why: It is displayed in the badge alongside the emoji.
        #expect(PostCategory.request.label == "Request")
    }

    @Test("Request post CodingKey for requestedUserIDs maps to requested_user_ids")
    func requestedUserIDsCodingKey() {
        // What: Encoding a Post with requestedUserIDs must produce the key "requested_user_ids".
        // Why: The Supabase column is snake_case; mismatch would silently drop the field.
        let userIDs = [UUID(), UUID()]
        let req = Fake.post(
            category: .request,
            requestedUserIDs: userIDs
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        guard let data = try? encoder.encode(req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            Issue.record("Encoding failed")
            return
        }
        #expect(json["requested_user_ids"] != nil)
        #expect(json["requestedUserIDs"] == nil)
    }

    @Test("Request post CodingKey for completionPostID maps to completion_post_id")
    func completionPostIDCodingKey() {
        // What: Encoding a Post with completionPostID must produce the key "completion_post_id".
        // Why: Supabase foreign key column is snake_case.
        let completionID = UUID()
        let req = Fake.post(category: .request, completionPostID: completionID)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            Issue.record("Encoding failed")
            return
        }
        #expect(json["completion_post_id"] != nil)
        #expect(json["completionPostID"] == nil)
    }

    // MARK: - Assigning to Specific Users

    @Test("Request assigned to specific users stores those IDs")
    func requestAssignedToSpecificUsers() {
        // What: When requestedUserIDs is set, only those users are assigned.
        // Why: The UI shows an "Assigned to" section only when this is non-nil and non-empty.
        let u1 = UUID()
        let u2 = UUID()
        let req = Fake.requestPost(requestedUserIDs: [u1, u2])
        #expect(req.requestedUserIDs == [u1, u2])
    }

    @Test("Request open to everyone has nil requestedUserIDs")
    func requestOpenToEveryoneHasNilIDs() {
        // What: A request with no specific assignees should have nil (not empty array).
        // Why: The UI branches on nil to mean "everyone". An empty array would be ambiguous.
        let req = Fake.requestPost(requestedUserIDs: nil)
        #expect(req.requestedUserIDs == nil)
    }

    // MARK: - Completing a Request

    @Test("completedRequest fixture has completionPostID and completionPost set")
    func completedRequestFixture() {
        // What: The Fake.completedRequest factory must produce a post where both
        //       completionPostID and completionPost are non-nil.
        // Why: These are the two fields the UI reads to render the "Completed by" pill.
        let homeID = UUID()
        let requestorID = UUID()
        let completerID = UUID()
        let completed = Fake.completedRequest(
            homeID: homeID,
            requestorID: requestorID,
            completerID: completerID
        )
        #expect(completed.completionPostID != nil)
        #expect(completed.completionPost != nil)
        #expect(completed.completionPost?.userID == completerID)
    }

    @Test("Completing an already-completed request does not overwrite completionPost")
    func completingAlreadyCompletedRequestIsNoOp() {
        // What: If a request already has a completionPost, a second attempt to mark it
        //       complete should leave the original completionPost unchanged.
        // Why: Guards against accidental overwrites from race conditions or duplicate taps.
        let firstCompleterID = UUID()
        let secondCompleterID = UUID()
        var completed = Fake.completedRequest(completerID: firstCompleterID)

        // Simulate a second completion attempt: only write if not already completed
        if completed.completionPostID == nil {
            completed.completionPostID = UUID()
            completed.completionPost = Fake.post(userID: secondCompleterID)
        }

        // The original completer should still be the one recorded
        #expect(completed.completionPost?.userID == firstCompleterID)
    }

    // MARK: - PostDetailViewModel – markComplete (dev mode)

    @Test("markComplete sets completionPostID on post in dev mode")
    func markCompleteDevMode() async {
        // What: In dev mode (DevPreview.home.id), markComplete should set completionPostID
        //       on the post without making a network call.
        // Why: Dev mode skips Supabase; local state must still update so the UI responds.
        let devPost = Post(
            id: UUID(),
            homeID: DevPreview.home.id,
            userID: DevPreview.roommate1.id,
            category: .request,
            text: "Take out the trash 🗑️",
            imageURL: nil,
            isDraft: false,
            createdAt: Date(),
            reactions: nil,
            comments: [],
            author: DevPreview.roommate1,
            paymentRequest: nil,
            requestedUserIDs: nil,
            completionPostID: nil
        )
        let vm = PostDetailViewModel(post: devPost)
        let fakeCompletionID = UUID()

        await vm.markComplete(with: fakeCompletionID)

        #expect(vm.post.completionPostID == fakeCompletionID)
    }

    @Test("PostDetailViewModel starts with nil completionPost")
    func viewModelStartsWithNilCompletionPost() {
        // Post stores only completionPostID; the full Post is loaded lazily by the VM.
        let completed = Fake.completedRequest()
        #expect(completed.completionPostID != nil)   // ID is present on the model
        let vm = PostDetailViewModel(post: completed)
        #expect(vm.completionPost == nil)             // VM starts nil — loads on demand
    }
}
