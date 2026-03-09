import SwiftUI

// MARK: - ReviewPostView

/// Step 3 of the post wizard. Shows a preview of everything and lets the user
/// publish immediately or save as a draft.
struct ReviewPostView: View {
    let capturedImage: UIImage?
    let category: PostCategory
    let captionText: String
    var wantsPaymentRequest: Bool = false
    var requestedUserIDs: [UUID] = []
    var choreSubcategory: ChoreSubcategory? = nil
    var reminderID: UUID? = nil

    // Shared VM that holds the draft created in step 1
    var vm: PostViewModel
    let home: Home
    var onBack: () -> Void
    var onSuccess: () -> Void

    @Environment(AppState.self) var appState

    // Shows a fun confirmation message after success before resetting
    @State private var successMessage: String? = nil

    // Payment request sheet
    @State private var showPaymentSheet = false
    @State private var paymentVM = PaymentViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Image preview ─────────────────────────────────────────
                imagePreview
                    .padding(.top, 16)

                // ── Category badge ────────────────────────────────────────
                HStack(spacing: 8) {
                    Text("\(category.emoji) \(category.label)")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                    if let sub = choreSubcategory, sub != .other {
                        Text("\(sub.emoji) \(sub.label)")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                // ── Caption ───────────────────────────────────────────────
                HStack {
                    if captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No caption")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text(captionText)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                // ── Assigned to (request posts only) ─────────────────────
                if category == .request && !requestedUserIDs.isEmpty {
                    let assignedNames = (home.members ?? [])
                        .filter { requestedUserIDs.contains($0.id) }
                        .map { $0.name }
                        .joined(separator: ", ")
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Assigned to")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(assignedNames)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

                // ── Success confirmation ───────────────────────────────────
                if let msg = successMessage {
                    Text(msg)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .transition(.scale.combined(with: .opacity))
                }

                // ── Upload progress ───────────────────────────────────────
                if vm.isUploadingImage {
                    VStack(spacing: 8) {
                        ProgressView(value: vm.uploadProgress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                            .padding(.horizontal, 20)
                        Text("Uploading photo... 📤")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

                // ── Error message ─────────────────────────────────────────
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                // ── Payment Request section (purchase posts only) ──────────
                if category == .purchase && successMessage == nil {
                    paymentRequestSection
                }

                // ── Action buttons ────────────────────────────────────────
                if successMessage == nil {
                    VStack(spacing: 12) {
                        // Primary: Publish now
                        Button {
                            submitPost(isDraft: false)
                        } label: {
                            HStack {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 4)
                                }
                                Text("Post it! 🚀")
                                    .font(.body.bold())
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                vm.isUploadingImage ? Color.orange.opacity(0.5) : Color.orange,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        .disabled(vm.isLoading || vm.isUploadingImage)

                        // Secondary: Save as draft
                        Button {
                            submitPost(isDraft: true)
                        } label: {
                            Text("Save Draft 💾")
                                .font(.body.bold())
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(vm.isLoading || vm.isUploadingImage)

                        // Back
                        Button("← Back") {
                            onBack()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Payment Request Section

    @ViewBuilder
    private var paymentRequestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("💸 Request Payment")
                    .font(.headline)
                Spacer()
            }

            if let request = paymentVM.paymentRequest {
                // Already configured — show summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("$\(request.totalAmount, specifier: "%.2f") — \(request.note)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("Split \(request.splits.count) way\(request.splits.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                Button("Edit Payment Request") {
                    showPaymentSheet = true
                }
                .font(.subheadline)
                .foregroundStyle(.orange)
            } else {
                // Not yet configured
                Button {
                    showPaymentSheet = true
                } label: {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                        Text("Set up payment request")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showPaymentSheet) {
            if let userID = appState.currentUser?.id,
               let draftID = vm.draft?.id {
                PaymentRequestView(
                    mode: .create(
                        postID: draftID,
                        homeID: home.id,
                        requestorID: userID,
                        members: home.members ?? []
                    )
                )
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Image preview

    @ViewBuilder
    private var imagePreview: some View {
        if let image = capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 120)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Text-only post")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Submit

    private func submitPost(isDraft: Bool) {
        guard let userID = appState.currentUser?.id else { return }
        Task {
            // Update VM state to match what the user selected in steps 1–3
            vm.selectedCategory = category
            vm.text = captionText
            // capturedImage is already set on the VM from CameraView

            // For request posts, stamp the requested user IDs onto the draft
            if category == .request, !requestedUserIDs.isEmpty {
                vm.draft?.requestedUserIDs = requestedUserIDs
            }

            // For chore posts, stamp the subcategory onto the draft
            if category == .chore {
                vm.draft?.choreSubcategory = choreSubcategory ?? .other
            }

            await vm.submitPost(homeID: home.id, userID: userID, isDraft: isDraft)

            // If a reminder was linked to this purchase post, clear it
            if vm.errorMessage == nil, !isDraft, let rid = reminderID {
#if DEBUG
                if home.id != DevPreview.home.id {
                    try? await HouseholdReminderService.shared.clearReminder(id: rid, byUserID: userID)
                }
#else
                try? await HouseholdReminderService.shared.clearReminder(id: rid, byUserID: userID)
#endif
            }

            if vm.errorMessage == nil {
                // Show a fun category-appropriate confirmation
                withAnimation(.spring(duration: 0.4)) {
                    successMessage = successCopy(for: category, isDraft: isDraft)
                }
                // Wait a moment, then hand control back to CameraTabView
                try? await Task.sleep(for: .seconds(2))
                onSuccess()
            }
        }
    }

    // MARK: - Fun confirmation copy

    private func successCopy(for category: PostCategory, isDraft: Bool) -> String {
        if isDraft {
            return "Draft saved! Come back to it 📝"
        }
        switch category {
        case .chore:    return "Chore logged! Nice work 💪"
        case .purchase: return "Receipts filed! 🧾"
        case .general:  return "Shared with the home! 📣"
        case .request:  return "Request posted! Waiting on the crew 🙋"
        }
    }
}
