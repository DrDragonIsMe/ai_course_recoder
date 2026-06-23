import Foundation

/// Represents the current state of the recording pipeline.
enum RecordingState: Equatable, CustomStringConvertible {
    case idle
    case configuring
    case recording
    case paused
    case stopping
    case stopped
    case exporting

    var description: String {
        switch self {
        case .idle: "Idle"
        case .configuring: "Configuring"
        case .recording: "Recording"
        case .paused: "Paused"
        case .stopping: "Stopping"
        case .stopped: "Stopped"
        case .exporting: "Exporting"
        }
    }

    var isActive: Bool {
        [.recording, .paused, .configuring, .stopping, .exporting].contains(self)
    }
}
