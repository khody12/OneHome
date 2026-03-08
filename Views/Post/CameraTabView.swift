import SwiftUI

// MARK: - Camera Step Enum

/// Tracks which step of the 3-step post wizard the user is on.
/// Associated values carry data forward through the funnel.
enum CameraStep {
    case camera
    case categorize(capturedImage: UIImage?)
    case review(capturedImage: UIImage?, category: PostCategory, text: String)
}

// MARK: - CameraTabView

/// Root view for the Camera tab. Owns the step state and a shared PostViewModel.
/// The VM is created once here and passed/observed through child views so that
/// the draft created in step 1 persists all the way to publish in step 3.
struct CameraTabView: View {
    let home: Home

    @State private var step: CameraStep = .camera
    @State private var vm = PostViewModel()
    @Environment(AppState.self) var appState

    var body: some View {
        ZStack {
            switch step {
            case .camera:
                CameraView(
                    onCapture: { image in
                        // Photo captured — move to categorize, draft already started in VM
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .categorize(capturedImage: image)
                        }
                    },
                    onSkip: {
                        // No photo — move to categorize with nil image
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .categorize(capturedImage: nil)
                        }
                    },
                    vm: vm,
                    home: home
                )
                .transition(.opacity)

            case .categorize(let capturedImage):
                CategorizeView(
                    capturedImage: capturedImage,
                    onNext: { category, text in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .review(capturedImage: capturedImage, category: category, text: text)
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

            case .review(let capturedImage, let category, let text):
                ReviewPostView(
                    capturedImage: capturedImage,
                    category: category,
                    captionText: text,
                    vm: vm,
                    home: home,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            step = .categorize(capturedImage: capturedImage)
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
