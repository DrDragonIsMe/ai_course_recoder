import Foundation
import SwiftUI
import ScreenCaptureKit
import Combine

/// View model that bridges the recording pipeline with the SwiftUI UI.
@MainActor
final class RecordingViewModel: ObservableObject {
    /// Recording state exposed to the UI.
    @Published var state: RecordingState = .idle {
        didSet {
            if state == .idle || state == .stopped {
                isRecording = false
            } else {
                isRecording = true
            }
        }
    }

    /// Human-readable duration.
    @Published var durationString: String = "00:00:00"

    /// Error message to display.
    @Published var errorMessage: String?

    /// Message shown when a recording is saved.
    @Published var outputReadyMessage: String?

    /// Available displays for selection.
    @Published var displays: [SCDisplay] = []

    /// Currently selected display.
    @Published var selectedDisplayID: CGDirectDisplayID?

    /// Recording configuration.
    @Published var config: RecordingConfig = .saved

    /// Whether the app is currently recording.
    @Published var isRecording: Bool = false

    /// Annotation session exposed to the annotation toolbar.
    @Published var annotationSession: AnnotationSession?

    /// Whether annotation drawing mode is currently active.
    @Published var isAnnotationDrawingModeEnabled: Bool = false

    /// Camera capture session for live preview.
    @Published var cameraSession: AVCaptureSession?

    /// Whether all required permissions are granted.
    @Published var hasRequiredPermissions: Bool = false

    private let pipeline = RecordingPipeline()
    private var durationTimer: Timer?
    private var floatingToolbar: FloatingToolbarWindow?

    init() {
        setupPipelineBindings()
    }

    // MARK: - Actions

    /// Load available displays and refresh permission state.
    func loadDisplays() async {
        displays = await ScreenCaptureService.availableDisplays()
        if let savedID = config.selectedDisplayID,
           let display = displays.first(where: { $0.displayID == savedID }) {
            selectedDisplayID = display.displayID
        } else if let first = displays.first {
            selectedDisplayID = first.displayID
            config.selectedDisplayID = first.displayID
        }

        await checkPermissions()
    }

    /// Check and request required permissions.
    func checkPermissions() async {
        await PermissionsManager.shared.checkAllPermissions()
        let permissions = PermissionsManager.shared
        hasRequiredPermissions = permissions.hasScreenPermission
            && (!config.enableCamera || permissions.hasCameraPermission)
            && (!config.enableMicrophone || permissions.hasMicrophonePermission)
    }

    /// Start recording.
    func startRecording() async {
        config.selectedDisplayID = selectedDisplayID
        RecordingConfig.saved = config

        await pipeline.start(config: config)
        // Show the toolbar after the overlay window is created so it stays on top.
        showFloatingToolbar()
    }

    /// Toggle annotation drawing mode on the overlay window.
    func toggleAnnotationDrawingMode() {
        pipeline.toggleAnnotationDrawingMode()
        isAnnotationDrawingModeEnabled.toggle()
    }

    /// Stop recording.
    func stopRecording() async {
        await pipeline.stop()
        hideFloatingToolbar()

        if let outputURL = pipeline.outputURL {
            outputReadyMessage = "Saved to \(outputURL.lastPathComponent)"
            // Open the containing folder to show the user where the file is
            let containingDir = outputURL.deletingLastPathComponent()
            NSWorkspace.shared.open(containingDir)
        }
    }

    private func showFloatingToolbar() {
        guard floatingToolbar == nil else { return }
        let toolbar = FloatingToolbarWindow(viewModel: self)
        toolbar.orderFrontRegardless()
        floatingToolbar = toolbar
    }

    private func hideFloatingToolbar() {
        floatingToolbar?.orderOut(nil)
        floatingToolbar = nil
    }

    /// Open the app settings/preferences window.
    func openSettingsWindow() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    /// Open privacy settings to grant screen recording permission.
    func openPrivacySettings() {
        PermissionsManager.shared.openPrivacySettings()
    }

    // MARK: - Setup

    private var cancellables = Set<AnyCancellable>()

    private func setupPipelineBindings() {
        // Observe pipeline state changes
        pipeline.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)

        pipeline.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.updateDurationString(duration)
            }
            .store(in: &cancellables)

        pipeline.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error.errorDescription
                }
            }
            .store(in: &cancellables)

        // Keep the UI's annotation session in sync with the pipeline.
        pipeline.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.annotationSession = self?.pipeline.annotationSession
                self?.cameraSession = self?.pipeline.cameraSession
            }
            .store(in: &cancellables)
    }

    private func updateDurationString(_ duration: TimeInterval) {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        durationString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
