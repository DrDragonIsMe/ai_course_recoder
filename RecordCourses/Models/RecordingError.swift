import Foundation

/// Errors that can occur during recording.
enum RecordingError: LocalizedError {
    case screenCapturePermissionDenied
    case cameraPermissionDenied
    case microphonePermissionDenied
    case noDisplayAvailable
    case captureFailed(Error)
    case writerFailed(Error)
    case exportFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .screenCapturePermissionDenied:
            return "Screen recording permission denied. Please grant it in System Settings > Privacy & Security > Screen Recording."
        case .cameraPermissionDenied:
            return "Camera permission denied. Please grant it in System Settings > Privacy & Security > Camera."
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please grant it in System Settings > Privacy & Security > Microphone."
        case .noDisplayAvailable:
            return "No display available for recording."
        case .captureFailed(let error):
            return "Screen capture failed: \(error.localizedDescription)"
        case .writerFailed(let error):
            return "Video writer failed: \(error.localizedDescription)"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .unknown(let message):
            return message
        }
    }
}
