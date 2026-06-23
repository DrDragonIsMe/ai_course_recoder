import Foundation
import ScreenCaptureKit
import AVFoundation

/// Wraps ScreenCaptureKit to capture the screen and deliver frames.
final class ScreenCaptureService: NSObject {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.recordcourses.screencapture")

    /// Callback for each captured screen frame.
    var onFrame: ((CMSampleBuffer, CMTime) -> Void)?

    /// Available displays for recording.
    static func availableDisplays() async -> [SCDisplay] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.displays
        } catch {
            return []
        }
    }

    /// Start capturing the specified display.
    func start(display: SCDisplay, config: RecordingConfig) async throws {
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = display.width
        streamConfig.height = display.height
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = config.showCursor
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        streamConfig.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream
        try await stream.startCapture()
    }

    /// Stop capturing.
    func stop() {
        stream?.stopCapture { _ in
            // capture stopped
        }
        stream = nil
    }
}

// MARK: - SCStreamOutput
extension ScreenCaptureService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutput sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        // Only process complete frames
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusValue = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusValue),
              status == .complete else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        onFrame?(sampleBuffer, timestamp)
    }
}

// MARK: - SCStreamDelegate
extension ScreenCaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Screen capture stopped with error: \(error.localizedDescription)")
    }
}
