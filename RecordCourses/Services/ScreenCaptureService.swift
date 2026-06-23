import Foundation
import ScreenCaptureKit
import AVFoundation
import os.log

/// Wraps ScreenCaptureKit to capture the screen and deliver frames.
final class ScreenCaptureService: NSObject {
    private static let logger = Logger(subsystem: "com.qijiayoudao.RecordCourses", category: "ScreenCaptureService")
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.recordcourses.screencapture")
    private var frameCount = 0
    private var rawCallbackCount = 0

    /// Callback for each captured screen frame.
    var onFrame: ((CMSampleBuffer, CMTime) -> Void)?

    /// Available displays for recording.
    static func availableDisplays() async -> [SCDisplay] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.displays
        } catch {
            Self.logger.error("availableDisplays failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Start capturing the specified display.
    func start(display: SCDisplay, config: RecordingConfig) async throws {
        Self.logger.info("start: display=\(display.displayID) \(display.width)x\(display.height) fps=\(config.fps)")

        // ScreenCaptureKit requires screen-recording permission. If denied,
        // startCapture() typically throws, but on some OS versions it succeeds
        // and then silently never delivers frames. Probe shareable content first
        // so we can log a clear cause instead of an empty file.
        do {
            let probe = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            Self.logger.info("screen permission probe OK: \(probe.displays.count) displays")
        } catch {
            Self.logger.error("screen permission probe failed: \(error.localizedDescription, privacy: .public)")
            throw RecordingError.screenCapturePermissionDenied
        }

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
        do {
            try await stream.startCapture()
            Self.logger.info("startCapture returned OK (stream started)")
        } catch {
            Self.logger.error("startCapture failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
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

        // Read frame status. ScreenCaptureKit delivers .idle frames when there is
        // nothing new to capture; we only want .complete frames for recording.
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        let statusValue = attachments?.first?[.status] as? Int ?? -1

        // Log the first few callbacks unconditionally so we can tell whether the
        // stream is delivering ANY frames (including idle) — distinguishes
        // "stream never calls back" from "stream only delivers idle frames".
        rawCallbackCount += 1
        if rawCallbackCount <= 5 || rawCallbackCount % 60 == 0 {
            Self.logger.info("didOutput raw #\(self.rawCallbackCount) status=\(statusValue)")
        }

        guard let status = SCFrameStatus(rawValue: statusValue),
              status == .complete else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        frameCount += 1
        if frameCount == 1 || frameCount % 30 == 0 {
            Self.logger.info("complete frame #\(self.frameCount) status=\(statusValue) ts=\(timestamp.value)")
        }
        onFrame?(sampleBuffer, timestamp)
    }
}

// MARK: - SCStreamDelegate
extension ScreenCaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Self.logger.error("stream stopped with error: \(error.localizedDescription, privacy: .public)")
    }
}
