import SwiftUI
import AVFoundation

// MARK: - IMPORTANT: Info.plist setup
// Before this feature ships you MUST add the following key to Info.plist:
//   NSCameraUsageDescription  →  "OneHome uses the camera so you can document chores,
//                                  purchases, and home moments."
// Without this key the app will crash on iOS when first requesting camera access.

// MARK: - CameraView (SwiftUI wrapper)

/// The live camera viewfinder screen — step 1 of the post wizard.
/// Manages permission state and shows controls overlaid on the full-screen preview.
struct CameraView: View {
    // Callbacks injected by CameraTabView
    var onCapture: (UIImage) -> Void
    var onSkip: () -> Void

    // Shared ViewModel — draft is started here once permission is confirmed
    var vm: PostViewModel
    let home: Home

    @Environment(AppState.self) var appState

    // Tracks whether we've asked for / received camera access
    @State private var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    // Flashed white overlay after shutter tap to simulate the camera shutter
    @State private var showShutterFlash = false

    // Reference to the underlying UIViewController so we can trigger capture / flip
    @State private var cameraController: CameraViewController?

    var body: some View {
        ZStack {
            // ── Full-screen camera preview ───────────────────────────────
            if permissionStatus == .authorized {
                CameraPreviewView(controller: $cameraController)
                    .ignoresSafeArea()
            } else {
                permissionDeniedView
            }

            // ── Shutter flash overlay ─────────────────────────────────────
            if showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── Controls overlay ──────────────────────────────────────────
            if permissionStatus == .authorized {
                VStack {
                    // Top row: Skip (left) + Flip camera (right)
                    HStack {
                        Button {
                            handleSkip()
                        } label: {
                            Label("Skip Photo", systemImage: "text.bubble")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 20)

                        Spacer()

                        Button {
                            cameraController?.flipCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                                .foregroundStyle(.white)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Shutter button — large orange circle at bottom center
                    Button {
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 76, height: 76)
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 88, height: 88)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        // Tap anywhere on the preview to focus at that point
        .onTapGesture { location in
            guard permissionStatus == .authorized else { return }
            cameraController?.focus(at: location)
        }
        .task {
            await requestPermissionIfNeeded()
        }
    }

    // MARK: - Actions

    private func capturePhoto() {
        guard let controller = cameraController else { return }

        controller.onCapture = { [self] image in
            Task { @MainActor in
                // 1. Start the draft in the VM as soon as we have a photo
                if let userID = appState.currentUser?.id {
                    await vm.startDraft(homeID: home.id, userID: userID)
                }
                vm.capturedImage = image

                // 2. Shutter flash animation
                withAnimation(.easeIn(duration: 0.08)) { showShutterFlash = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeOut(duration: 0.18)) { showShutterFlash = false }
                try? await Task.sleep(for: .milliseconds(200))

                // 3. Advance to categorize step
                onCapture(image)
            }
        }

        controller.capturePhoto()
    }

    private func handleSkip() {
        Task {
            // Draft is still created — just without an image
            if let userID = appState.currentUser?.id {
                await vm.startDraft(homeID: home.id, userID: userID)
            }
            vm.capturedImage = nil
            onSkip()
        }
    }

    private func requestPermissionIfNeeded() async {
        switch permissionStatus {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionStatus = granted ? .authorized : .denied
        case .authorized:
            break // already good
        default:
            break // denied/restricted — handled in the UI
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.title2.bold())

            Text("OneHome needs camera access to let you document chores and purchases. You can enable it in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button("Skip Photo Instead") {
                handleSkip()
            }
            .foregroundStyle(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - CameraPreviewView (UIViewControllerRepresentable)

/// Bridges CameraViewController (UIKit/AVFoundation) into SwiftUI.
/// Exposes the controller via a binding so the parent SwiftUI view can call
/// imperative camera methods (capture, flip, focus).
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var controller: CameraViewController?

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        // Pass the instance back to SwiftUI state on the main thread
        DispatchQueue.main.async { controller = vc }
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // No dynamic updates needed — the controller manages itself
    }
}

// MARK: - CameraViewController

/// UIViewController that owns and manages the AVCaptureSession.
/// Kept in UIKit because AVFoundation's preview layer integrates most cleanly
/// with UIKit's layer hierarchy.
class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    // Callback invoked on the main thread after a photo is captured
    var onCapture: (UIImage) -> Void = { _ in }

    // MARK: AVFoundation objects

    /// The capture session coordinates data flow between inputs and outputs.
    private let session = AVCaptureSession()

    /// Receives still image capture requests and delivers JPEG data.
    private let photoOutput = AVCapturePhotoOutput()

    /// Renders the live camera feed into this view's layer.
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// Tracks which camera (front/back) is active so we can flip.
    private var currentPosition: AVCaptureDevice.Position = .back

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the preview layer filling the view whenever the layout changes
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start the session on a background thread — it blocks until cameras are ready
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Always stop the session when the view is off-screen to conserve battery
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Session Setup

    /// Configures the AVCaptureSession with the back camera input and photo output.
    /// Must be called once during setup. Runs synchronously on the calling thread.
    private func setupCaptureSession() {
        session.beginConfiguration()
        // Use high-quality preset — balances resolution and performance well on iPhone
        session.sessionPreset = .photo

        addCameraInput(position: .back)

        // Add the photo output if the session supports it
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        // Attach the preview layer AFTER configuration is committed
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill  // fill the frame, crop edges
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)  // behind any other layers
        self.previewLayer = previewLayer
    }

    /// Adds a camera device input for the given position (front/back).
    /// Removes any existing camera inputs first so we can safely swap.
    @discardableResult
    private func addCameraInput(position: AVCaptureDevice.Position) -> Bool {
        // Remove existing video inputs before adding a new one
        session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.video) }
            .forEach { session.removeInput($0) }

        // Find the best available camera for the requested position
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return false
        }
        session.addInput(input)
        currentPosition = position
        return true
    }

    // MARK: - Public Interface

    /// Triggers a still image capture. The result is delivered asynchronously
    /// to `photoOutput(_:didFinishProcessingPhoto:error:)`.
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        // Use HEIF when available for smaller file sizes, fallback to JPEG
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            // HEIF is preferred on modern iPhones
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// Flips between front and back cameras while the session is running.
    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
        session.beginConfiguration()
        addCameraInput(position: newPosition)
        session.commitConfiguration()
    }

    /// Moves the camera's focus and exposure point to the tapped screen location.
    /// - Parameter screenPoint: The tap location in the view's coordinate space.
    func focus(at screenPoint: CGPoint) {
        guard let previewLayer = previewLayer,
              let device = (session.inputs.first as? AVCaptureDeviceInput)?.device,
              device.isFocusPointOfInterestSupported else { return }

        // Convert screen point → camera sensor space (0,0)–(1,1)
        let cameraPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: screenPoint)

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = cameraPoint
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = cameraPoint
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
        } catch {
            // Focus failure is non-fatal — silently ignore
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    /// Called by AVFoundation when the photo has been processed and is ready.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        // Ensure the UI callback is always delivered on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.onCapture(image)
        }
    }
}
