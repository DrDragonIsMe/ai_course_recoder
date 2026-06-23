import Foundation
import ScreenCaptureKit

/// Configuration for a recording session.
struct RecordingConfig: Codable, Equatable {
    // Capture target
    var captureMode: CaptureMode = .fullScreen
    var selectedDisplayID: CGDirectDisplayID? = nil

    // Video settings
    var videoCodec: VideoCodec = .h264
    var quality: Quality = .high
    var fps: Int = 30

    // Camera
    var enableCamera: Bool = true
    var cameraPosition: CameraPosition = .bottomRight
    var cameraSize: CameraSize = .medium

    // Audio
    var enableMicrophone: Bool = true

    // Cursor
    var showCursor: Bool = true

    // Layout
    var layout: RecordingLayout = .cornerPIP()

    // Output
    var outputFormat: OutputFormat = .mov
    var outputDirectory: URL? = nil

    enum CodingKeys: String, CodingKey {
        case captureMode, selectedDisplayID, videoCodec, quality, fps
        case enableCamera, cameraPosition, cameraSize, enableMicrophone
        case showCursor, outputFormat, outputDirectory, layout
    }

    // MARK: - Nested Enums

    enum VideoCodec: String, Codable, CaseIterable {
        case h264
        case hevc

        var avCodec: AVVideoCodecType {
            switch self {
            case .h264: return .h264
            case .hevc: return .hevc
            }
        }
    }

    enum Quality: String, Codable, CaseIterable {
        case low, medium, high

        var bitrateMultiplier: Int {
            switch self {
            case .low: return 50
            case .medium: return 100
            case .high: return 200
            }
        }
    }

    enum CameraPosition: String, Codable, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        var displayName: String {
            switch self {
            case .topLeft: return "Top Left"
            case .topRight: return "Top Right"
            case .bottomLeft: return "Bottom Left"
            case .bottomRight: return "Bottom Right"
            }
        }

        var anchorX: CGFloat {
            switch self {
            case .topLeft, .bottomLeft: return 0
            case .topRight, .bottomRight: return 1
            }
        }

        var anchorY: CGFloat {
            switch self {
            case .topLeft, .topRight: return 0
            case .bottomLeft, .bottomRight: return 1
            }
        }
    }

    enum CameraSize: String, Codable, CaseIterable {
        case small, medium, large

        var aspectRatioMultiplier: CGFloat {
            switch self {
            case .small: return 0.15
            case .medium: return 0.22
            case .large: return 0.30
            }
        }
    }

    enum OutputFormat: String, Codable, CaseIterable {
        case mov, mp4

        var fileType: AVFileType {
            switch self {
            case .mov: return .mov
            case .mp4: return .mp4
            }
        }
    }

    // MARK: - Defaults

    static var `default`: RecordingConfig {
        RecordingConfig()
    }

    // MARK: - Persistence

    static var saved: RecordingConfig {
        get {
            if let data = UserDefaults.standard.data(forKey: "RecordingConfig"),
               let config = try? JSONDecoder().decode(RecordingConfig.self, from: data) {
                return config
            }
            return .default
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "RecordingConfig")
            }
        }
    }
}
