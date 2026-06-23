import Foundation
import AVFoundation

/// Helpers for device discovery.
enum DeviceHelper {
    /// Get the default camera device name.
    static func defaultCameraName() -> String {
        let cameras = CameraCaptureService.availableCameras()
        return cameras.first?.localizedName ?? "No camera"
    }

    /// Get the default microphone device name.
    static func defaultMicrophoneName() -> String {
        let mics = AudioCaptureService.availableMicrophones()
        return mics.first?.localizedName ?? "No microphone"
    }

    /// List all camera device names.
    static func cameraNames() -> [String] {
        CameraCaptureService.availableCameras().map { $0.localizedName }
    }

    /// List all microphone device names.
    static func microphoneNames() -> [String] {
        AudioCaptureService.availableMicrophones().map { $0.localizedName }
    }
}
