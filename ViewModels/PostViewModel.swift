import SwiftUI
import PhotosUI

@Observable
class PostViewModel {
    var draft: Post?
    var selectedCategory: PostCategory = .chore
    var text = ""
    var selectedPhoto: PhotosPickerItem?
    var uploadedImageURL: String?
    var isLoading = false
    var isUploadingImage: Bool = false
    var uploadProgress: Double = 0.0
    var errorMessage: String?
    var isPosted = false

    /// The UIImage captured from the camera (nil for text-only / library-pick posts).
    /// Held here so ReviewPostView can access it without passing it through every layer.
    var capturedImage: UIImage?

    // Called when camera tab opens — create draft immediately
    func startDraft(homeID: UUID, userID: UUID) async {
        guard draft == nil else { return }
#if DEBUG
        if homeID == DevPreview.home.id {
            draft = Post(
                id: UUID(), homeID: homeID, userID: userID,
                category: selectedCategory, text: "", imageURL: nil,
                isDraft: true, createdAt: Date(),
                reactions: nil, comments: [], author: DevPreview.user
            )
            return
        }
#endif
        isLoading = true
        do {
            draft = try await PostService.shared.createDraft(homeID: homeID, userID: userID, category: selectedCategory)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func saveDraft() async {
        guard var d = draft else { return }
        d.text = text
        d.category = selectedCategory
        d.imageURL = uploadedImageURL
        try? await PostService.shared.updateDraft(d)
    }

    func publish(homeID: UUID, userID: UUID) async {
        guard let d = draft else { return }
        isLoading = true
        do {
            try await PostService.shared.publish(postID: d.id)
            try await MetricsService.shared.recordPost(userID: userID, homeID: homeID, category: selectedCategory)
            isPosted = true
            draft = nil
            text = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Unified submit function used by the camera wizard.
    /// When `isDraft` is true, updates the draft in-place but does NOT publish.
    /// When `isDraft` is false, uploads any captured image, saves the latest details, then publishes.
    func submitPost(homeID: UUID, userID: UUID, isDraft: Bool) async {
        // A draft must have been created in step 1 before we can submit
        guard var d = draft else {
            errorMessage = "No draft found. Please restart."
            return
        }
#if DEBUG
        if homeID == DevPreview.home.id {
            if !isDraft { isPosted = true; draft = nil }
            return
        }
#endif

        isLoading = true
        errorMessage = nil

        // Stamp the latest category and text onto the draft
        d.text = text
        d.category = selectedCategory

        do {
            // If publishing and a captured image is present, upload it first
            if !isDraft, let image = capturedImage {
                isUploadingImage = true
                uploadProgress = 0.0
                do {
                    let url = try await StorageService.shared.uploadPostImage(
                        image,
                        homeID: homeID,
                        userID: userID,
                        postID: d.id
                    )
                    uploadedImageURL = url
                    uploadProgress = 1.0
                } catch {
                    isUploadingImage = false
                    isLoading = false
                    errorMessage = "Image upload failed: \(error.localizedDescription)"
                    return
                }
                isUploadingImage = false
            }

            d.imageURL = uploadedImageURL

            // Always persist the latest content first
            try await PostService.shared.updateDraft(d)

            if !isDraft {
                // Publish: flip is_draft → false and record metrics
                try await PostService.shared.publish(postID: d.id)
                try await MetricsService.shared.recordPost(
                    userID: userID,
                    homeID: homeID,
                    category: selectedCategory
                )
                isPosted = true
                draft = nil
            }
            // If saving as draft we leave `draft` intact so the user can come back
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func reset() {
        draft = nil
        text = ""
        selectedPhoto = nil
        uploadedImageURL = nil
        capturedImage = nil
        isPosted = false
        isUploadingImage = false
        uploadProgress = 0.0
        errorMessage = nil
    }
}
