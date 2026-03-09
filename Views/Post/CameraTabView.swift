import SwiftUI

// MARK: - Camera Step Enum

/// Tracks which step of the 3-step post wizard the user is on.
/// Associated values carry data forward through the funnel.
enum CameraStep {
    case camera
    case categorize(capturedImage: UIImage?, members: [User])
    case review(capturedImage: UIImage?, category: PostCategory, text: String, wantsPayment: Bool, requestedUserIDs: [UUID], choreSubcategory: ChoreSubcategory?, reminderID: UUID?)
}

// MARK: - CameraTabView

/// Root view for the Camera tab. Owns the step state and a shared PostViewModel.
/// The VM is created once here and passed/observed through child views so that
/// the draft created in step 1 persists all the way to publish in step 3.
struct CameraTabView: View {
    let home: Home

    @State private var step: CameraStep = .camera
    @State private var vm = PostViewModel()
    @State private var dueReminders: [HouseholdReminder] = []
    @Environment(AppState.self) var appState

    var body: some View {
        ZStack {
            switch step {
            case .camera:
                CameraView(
                    onCapture: { image in
                        // Photo captured — move to categorize, draft already started in VM
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .categorize(capturedImage: image, members: home.members ?? [])
                        }
                    },
                    onSkip: {
                        // No photo — move to categorize with nil image
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .categorize(capturedImage: nil, members: home.members ?? [])
                        }
                    },
                    vm: vm,
                    home: home
                )
                .transition(.opacity)

            case .categorize(let capturedImage, let members):
                CategorizeView(
                    capturedImage: capturedImage,
                    members: members,
                    dueReminders: dueReminders,
                    onNext: { category, text, wantsPayment, requestedUserIDs, choreSubcategory, reminderID in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .review(capturedImage: capturedImage, category: category, text: text, wantsPayment: wantsPayment, requestedUserIDs: requestedUserIDs, choreSubcategory: choreSubcategory, reminderID: reminderID)
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .camera
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .review(let capturedImage, let category, let text, let wantsPayment, let requestedUserIDs, let choreSubcategory, let reminderID):
                ReviewPostView(
                    capturedImage: capturedImage,
                    category: category,
                    captionText: text,
                    wantsPaymentRequest: wantsPayment,
                    requestedUserIDs: requestedUserIDs,
                    choreSubcategory: choreSubcategory,
                    reminderID: reminderID,
                    vm: vm,
                    home: home,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .categorize(capturedImage: capturedImage, members: home.members ?? [])
                        }
                    },
                    onSuccess: {
                        // After publish/draft, reset the whole wizard back to camera
                        withAnimation(.easeInOut(duration: 0.4)) {
                            step = .camera
                            vm.reset()
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: stepIndex)
        .task { await loadDueReminders() }
    }

    private func loadDueReminders() async {
#if DEBUG
        if home.id == DevPreview.home.id {
            dueReminders = DevPreview.reminders.filter { $0.isDue }
            return
        }
#endif
        let all = try? await HouseholdReminderService.shared.fetchReminders(for: home.id)
        dueReminders = (all ?? []).filter { $0.isDue }
    }

    /// A numeric representation of the current step used to drive animation.
    private var stepIndex: Int {
        switch step {
        case .camera: return 0
        case .categorize: return 1
        case .review: return 2
        }
    }
}
