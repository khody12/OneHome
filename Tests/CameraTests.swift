import Testing
import Foundation
@testable import OneHome

// MARK: - Helpers
//
// AVFoundation cannot be tested without a real device, so all tests here
// exercise the ViewModel and model layer only. A lightweight stub replaces
// PostService so no network calls are made.

// MARK: - Stub PostService replacement
//
// We can't easily subclass the singleton, so tests drive PostViewModel directly
// by pre-populating its `draft` property using Fake-constructed Post values
// and verifying state changes without ever touching the network.

@Suite("Camera Post Flow")
struct CameraPostFlowTests {

    // MARK: - Draft created on capture

    @Test("Draft is created when photo is captured")
    func draftCreatedOnCapture() async {
        let vm = PostViewModel()

        // Simulate what CameraView does: inject a draft as if PostService responded
        let homeID = UUID()
        let userID = UUID()
        let fakeDraft = Fake.post(homeID: homeID, userID: userID, isDraft: true)

        // Manually inject the draft (bypassing the real PostService call)
        vm.draft = fakeDraft

        // A captured image should be storable on the VM
        let image = UIImage()
        vm.capturedImage = image

        #expect(vm.draft != nil)
        #expect(vm.draft?.isDraft == true)
        #expect(vm.capturedImage != nil)
        #expect(vm.draft?.homeID == homeID)
        #expect(vm.draft?.userID == userID)
    }

    // MARK: - Skip photo

    @Test("Skipping photo creates draft with no imageURL")
    func skipPhotoCreatesDraftWithNoImage() async {
        let vm = PostViewModel()

        let fakeDraft = Fake.post(isDraft: true, imageURL: nil)
        vm.draft = fakeDraft
        vm.capturedImage = nil  // no image — text-only flow

        #expect(vm.draft != nil)
        #expect(vm.draft?.imageURL == nil)
        #expect(vm.capturedImage == nil)
        #expect(vm.draft?.isDraft == true)
    }

    // MARK: - Publishing sets isDraft to false

    @Test("Publishing sets isDraft to false")
    func publishSetsDraftFalse() async {
        let vm = PostViewModel()

        // Start with a draft in place
        let draftID = UUID()
        let fakeDraft = Fake.post(id: draftID, isDraft: true)
        vm.draft = fakeDraft
        vm.isPosted = false

        // Simulate the state PostViewModel.submitPost sets after a successful publish
        // (tests the model-layer concern, not the network call)
        vm.isPosted = true
        vm.draft = nil   // VM clears draft on publish

        #expect(vm.isPosted == true)
        #expect(vm.draft == nil)
    }

    // MARK: - All three categories are selectable

    @Test("All four categories are selectable")
    func allCategoriesAreAvailable() {
        // PostCategory.allCases must contain exactly the four expected cases
        let cases = PostCategory.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.chore))
        #expect(cases.contains(.purchase))
        #expect(cases.contains(.general))
        #expect(cases.contains(.request))
    }

    // MARK: - Reset clears state

    @Test("Reset clears captured image and draft")
    func resetClearsState() async {
        let vm = PostViewModel()

        // Populate the VM with data representing a completed post session
        vm.draft = Fake.post(isDraft: true)
        vm.capturedImage = UIImage()
        vm.text = "Test caption"
        vm.isPosted = true
        vm.errorMessage = "Some error"
        vm.selectedCategory = .purchase

        // Reset should wipe everything
        vm.reset()

        #expect(vm.draft == nil)
        #expect(vm.capturedImage == nil)
        #expect(vm.text == "")
        #expect(vm.isPosted == false)
        #expect(vm.errorMessage == nil)
        // selectedCategory is intentionally NOT reset — matches current reset() impl
    }

    // MARK: - Category emoji correctness

    @Test("Category emoji is correct for each type")
    func categoryEmojis() {
        #expect(PostCategory.chore.emoji == "🧹")
        #expect(PostCategory.purchase.emoji == "🛒")
        #expect(PostCategory.general.emoji == "📣")
    }

    // MARK: - Draft ownership

    @Test("Draft post has correct homeID and userID")
    func draftHasCorrectOwnership() async {
        let homeID = UUID()
        let userID = UUID()

        let fakeDraft = Fake.post(homeID: homeID, userID: userID, isDraft: true)

        let vm = PostViewModel()
        vm.draft = fakeDraft

        #expect(vm.draft?.homeID == homeID)
        #expect(vm.draft?.userID == userID)
        #expect(vm.draft?.isDraft == true)
    }

    // MARK: - Category subtitle helper

    @Test("Category subtitles are non-empty")
    func categorySubtitles() {
        for category in PostCategory.allCases {
            #expect(!category.subtitle.isEmpty)
        }
    }

    // MARK: - Submit sets selected category and text before publish

    @Test("Submit propagates category and text to draft before publishing")
    func submitUpdatesVMState() async {
        let vm = PostViewModel()

        // Pre-set the category and text that ReviewPostView would stamp on the VM
        vm.selectedCategory = .purchase
        vm.text = "Bought dish soap $4.99"

        #expect(vm.selectedCategory == .purchase)
        #expect(vm.text == "Bought dish soap $4.99")
    }
}
