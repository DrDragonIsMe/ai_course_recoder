import Foundation
import ScreenCaptureKit
import AVFoundation

/// Manages system permissions required for recording.
@MainActor
final class PermissionsManager {
    static let shared = PermissionsManager()

    private(set) var hasScreenPermission = false
    private(set) var hasCameraPermission = false
    private(set) var hasMicrophonePermission = false

    private init() {}

    /// Check all permissions and request if needed.
    func checkAllPermissions() async {
        await checkScreenPermission()
        await checkCameraPermission()
        await checkMicrophonePermission()
    }

    /// Check screen recording permission.
    ///
    /// `SCShareableContent` is an unreliable probe: it can return a display list
    /// even when the actual frame-capture permission is denied or stale (common
    /// with adhoc-signed debug builds whose signature changes on every rebuild —
    /// macOS invalidates the previously-granted TCC entry). Use Core Graphics'
    /// explicit preflight API instead, which reflects the real capture grant.
    func checkScreenPermission() async {
        hasScreenPermission = CGPreflightScreenCaptureAccess()
    }

    /// Request screen recording permission. This should be called from a user
    /// action (button click) because macOS may suppress the prompt when it is
    /// triggered automatically at launch.
    @discardableResult
    func requestScreenPermission() async -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        hasScreenPermission = granted
        return granted
    }

    /// Check camera permission.
    func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            hasCameraPermission = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            hasCameraPermission = false
        @unknown default:
            hasCameraPermission = false
        }
    }

    /// Check microphone permission.
    func checkMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            hasMicrophonePermission = true
        case .notDetermined:
            hasMicrophonePermission = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            hasMicrophonePermission = false
        @unknown default:
            hasMicrophonePermission = false
        }
    }

    /// Open System Settings to the Privacy & Security panel.
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenRecording") {
            NSWorkspace.shared.open(url)
        }
    }
}
