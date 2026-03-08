import Testing
import Foundation
@testable import OneHome

// MARK: - Testable PostViewModel
//
// Subclass of PostViewModel that replaces PostService.shared and
// MetricsService.shared with injected mocks. Each overridden method
// mirrors the production logic exactly — only the service calls differ.

@Observable
final class TestablePostViewModel: PostViewModel {
    let postService: MockPostService
    let metricsService: MockMetricsService

    init(postService: MockPostService, metricsService: MockMetricsService) {
        self.postService = postService
        self.metricsService = metricsService
    }

    override func startDraft(homeID: UUID, userID: UUID) async {
        guard draft == nil else { return }
        isLoading = true
        do {
            draft = try await postService.createDraft(homeID: homeID, userID: userID, category: selectedCategory)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    override func saveDraft() async {
        guard var d = draft else { return }
        d.text = text
        d.category = selectedCategory
        d.imageURL = uploadedImageURL
        try? await postService.updateDraft(d)
    }

    override func publish(homeID: UUID, userID: UUID) async {
        guard let d = draft else { return }
        isLoading = true
        do {
            try await postService.publish(postID: d.id)
            try await metricsService.recordPost(userID: userID, homeID: homeID, category: selectedCategory, amount: 0)
            isPosted = true
            draft = nil
            text = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - PostViewModelTests

@Suite("PostViewModel")
struct PostViewModelTests {

    // MARK: Helpers

    private func makeSUT() -> (vm: TestablePostViewModel, postSvc: MockPostService, metricsSvc: MockMetricsService) {
        let postSvc = MockPostService()
        let metricsSvc = MockMetricsService()
        let vm = TestablePostViewModel(postService: postSvc, metricsService: metricsSvc)
        return (vm, postSvc, metricsSvc)
    }

    // MARK: - startDraft

    @Test("startDraft calls createDraft and sets draft")
    func startDraftCallsServiceAndSetsDraft() async {
        // WHY: Opening the camera tab must immediately create a DB draft so
        // that unsaved work is persisted even if the user is interrupted.
        let (vm, postSvc, _) = makeSUT()
        let homeID = UUID()
        let userID = UUID()
        let expectedDraft = Fake.draftPost(homeID: homeID, userID: userID)
        postSvc.draftToReturn = expectedDraft

        await vm.startDraft(homeID: homeID, userID: userID)

        #expect(postSvc.createDraftCallCount == 1)
        #expect(postSvc.lastDraftHomeID == homeID)
        #expect(postSvc.lastDraftUserID == userID)
        #expect(vm.draft?.id == expectedDraft.id)
        #expect(vm.isLoading == false)
    }

    @Test("startDraft passes selectedCategory to createDraft")
    func startDraftPassesCategory() async {
        // WHY: The category the user pre-selects must flow through to the draft
        // so the DB row has the right category from the start.
        let (vm, postSvc, _) = makeSUT()
        vm.selectedCategory = .purchase

        await vm.startDraft(homeID: UUID(), userID: UUID())

        #expect(postSvc.lastDraftCategory == .purchase)
    }

    @Test("startDraft only creates one draft even if called twice")
    func startDraftIdempotent() async {
        // WHY: If the camera tab re-appears (e.g. user switches tabs and back),
        // we must NOT create a second draft. The guard `draft == nil` handles this.
        let (vm, postSvc, _) = makeSUT()
        let existingDraft = Fake.draftPost()
        postSvc.draftToReturn = existingDraft

        await vm.startDraft(homeID: UUID(), userID: UUID())
        await vm.startDraft(homeID: UUID(), userID: UUID())

        // createDraft should only be called once
        #expect(postSvc.createDraftCallCount == 1)
    }

    @Test("startDraft sets errorMessage on service failure")
    func startDraftErrorSetsMessage() async {
        // WHY: If the DB is unreachable, startDraft fails. The user should
        // see an error rather than a blank camera tab with no indication of failure.
        let (vm, postSvc, _) = makeSUT()
        postSvc.errorToThrow = AppError.networkError("connection lost")

        await vm.startDraft(homeID: UUID(), userID: UUID())

        #expect(vm.draft == nil)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test("startDraft leaves draft nil when service throws")
    func startDraftLeavesdraftNilOnError() async {
        // WHY: A failed createDraft must not leave a phantom non-nil draft
        // that references a non-existent DB row.
        let (vm, postSvc, _) = makeSUT()
        postSvc.errorToThrow = AppError.notFound

        await vm.startDraft(homeID: UUID(), userID: UUID())

        #expect(vm.draft == nil)
    }

    // MARK: - publish

    @Test("publish calls publish service and recordPost then resets state")
    func publishCallsServicesAndResetsState() async {
        // WHY: A successful publish must (1) flip the draft to published in DB,
        // (2) update metrics so slacker detection works, and (3) clear local state
        // so the camera tab is ready for the next post.
        let (vm, postSvc, metricsSvc) = makeSUT()
        let homeID = UUID()
        let userID = UUID()
        let draft = Fake.draftPost(homeID: homeID, userID: userID)
        postSvc.draftToReturn = draft

        // Set up draft first
        await vm.startDraft(homeID: homeID, userID: userID)
        vm.text = "Cleaned the oven 🧹"
        vm.selectedCategory = .chore

        await vm.publish(homeID: homeID, userID: userID)

        #expect(postSvc.publishCallCount == 1)
        #expect(postSvc.lastPublishedPostID == draft.id)
        #expect(metricsSvc.recordPostCallCount == 1)
        #expect(metricsSvc.lastRecordedUserID == userID)
        #expect(metricsSvc.lastRecordedHomeID == homeID)
        #expect(metricsSvc.lastRecordedCategory == .chore)
        #expect(vm.isPosted == true)
        #expect(vm.draft == nil)
        #expect(vm.text == "")
        #expect(vm.isLoading == false)
    }

    @Test("publish without a draft is a no-op")
    func publishWithoutDraftIsNoop() async {
        // WHY: Calling publish before startDraft (e.g. deep-link edge case)
        // must not crash or make service calls — the guard protects against this.
        let (vm, postSvc, metricsSvc) = makeSUT()

        await vm.publish(homeID: UUID(), userID: UUID())

        #expect(postSvc.publishCallCount == 0)
        #expect(metricsSvc.recordPostCallCount == 0)
        #expect(vm.isPosted == false)
    }

    @Test("publish sets errorMessage when post service throws")
    func publishSetsErrorOnPostServiceFailure() async {
        // WHY: If publish fails (e.g. offline), the draft must stay intact
        // so the user can retry — and an error must appear.
        let (vm, postSvc, _) = makeSUT()
        let draft = Fake.draftPost()
        postSvc.draftToReturn = draft

        await vm.startDraft(homeID: UUID(), userID: UUID())

        // Make publish throw
        postSvc.errorToThrow = AppError.networkError("publish failed")
        await vm.publish(homeID: UUID(), userID: UUID())

        #expect(vm.errorMessage != nil)
        #expect(vm.isPosted == false)
        // Draft is NOT cleared on failure — user can retry
        #expect(vm.draft?.id == draft.id)
        #expect(vm.isLoading == false)
    }

    @Test("publish sets errorMessage when metrics service throws")
    func publishSetsErrorOnMetricsFailure() async {
        // WHY: recordPost failure (metrics DB unavailable) is a real path.
        // The post itself was published but metrics didn't update — error shown.
        let (vm, postSvc, metricsSvc) = makeSUT()
        let draft = Fake.draftPost()
        postSvc.draftToReturn = draft

        await vm.startDraft(homeID: UUID(), userID: UUID())

        metricsSvc.errorToThrow = AppError.networkError("metrics failed")
        await vm.publish(homeID: UUID(), userID: UUID())

        #expect(vm.errorMessage != nil)
        #expect(vm.isPosted == false)
    }

    // MARK: - reset

    @Test("reset clears all state")
    func resetClearsAllState() async {
        // WHY: After navigating away from the camera tab, all ephemeral state
        // must be wiped so the next post starts clean.
        let (vm, postSvc, _) = makeSUT()
        let draft = Fake.draftPost()
        postSvc.draftToReturn = draft

        await vm.startDraft(homeID: UUID(), userID: UUID())
        vm.text = "Some text"
        vm.uploadedImageURL = "https://example.com/photo.jpg"
        vm.errorMessage = "Some old error"

        vm.reset()

        #expect(vm.draft == nil)
        #expect(vm.text == "")
        #expect(vm.selectedPhoto == nil)
        #expect(vm.uploadedImageURL == nil)
        #expect(vm.isPosted == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("reset on a clean ViewModel is safe (no crash)")
    func resetOnCleanVMIsSafe() {
        // WHY: reset() is called in various teardown paths; calling it
        // when nothing is set should be a safe no-op.
        let (vm, _, _) = makeSUT()
        vm.reset()

        #expect(vm.draft == nil)
        #expect(vm.text == "")
        #expect(vm.errorMessage == nil)
    }

    // MARK: - saveDraft

    @Test("saveDraft updates draft text and category before sending to service")
    func saveDraftSyncsFieldsToService() async {
        // WHY: The VM keeps text and selectedCategory as separate fields.
        // saveDraft must sync those into the draft struct before the update call.
        let (vm, postSvc, _) = makeSUT()
        let draft = Fake.draftPost()
        postSvc.draftToReturn = draft

        await vm.startDraft(homeID: UUID(), userID: UUID())
        vm.text = "Updated chore text 🧹"
        vm.selectedCategory = .purchase
        vm.uploadedImageURL = "https://example.com/img.jpg"

        await vm.saveDraft()

        #expect(postSvc.updateDraftCallCount == 1)
        #expect(postSvc.lastUpdatedDraft?.text == "Updated chore text 🧹")
        #expect(postSvc.lastUpdatedDraft?.category == .purchase)
        #expect(postSvc.lastUpdatedDraft?.imageURL == "https://example.com/img.jpg")
    }

    @Test("saveDraft with no draft is a no-op")
    func saveDraftWithNoDraftIsNoop() async {
        // WHY: If startDraft was never called (or failed), saveDraft
        // must not call the service — there's nothing to update.
        let (vm, postSvc, _) = makeSUT()

        await vm.saveDraft()

        #expect(postSvc.updateDraftCallCount == 0)
    }
}
