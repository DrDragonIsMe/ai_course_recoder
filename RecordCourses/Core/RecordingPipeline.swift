import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

/// Orchestrates the full recording lifecycle: screen + camera + audio → file.
@MainActor
final class RecordingPipeline: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var error: RecordingError?
    @Published var outputURL: URL?

    /// Active annotation session while recording. Exposed so the UI can show the annotation toolbar.
    private(set) var annotationSession: AnnotationSession?

    /// Camera capture session, exposed for live preview.
    private(set) var cameraSession: AVCaptureSession?

    private var screenCapture: ScreenCaptureService?
    private var cameraCapture: CameraCaptureService?
    private var audioCapture: AudioCaptureService?
    private var assetWriter: RecordingAssetWriter?
    private var videoCompositor: VideoCompositor?
    private var annotationOverlayWindow: AnnotationOverlayWindow?

    private var startTime: Date?
    private var timer: Timer?
    private var config: RecordingConfig = .saved

    // MARK: - Public

    /// Start recording with the given configuration.
    func start(config: RecordingConfig = .saved) async {
        self.config = config
        RecordingConfig.saved = config

        state = .configuring

        do {
            // 1. Discover display
            let displays = await ScreenCaptureService.availableDisplays()
            guard let targetDisplay = displays.first(where: { $0.displayID == config.selectedDisplayID })
                ?? displays.first else {
                throw RecordingError.noDisplayAvailable
            }

            // 2. Generate output file URL
            let outputURL = generateOutputURL()

            // 3. Initialize asset writer
            let writer = RecordingAssetWriter()
            try writer.start(url: outputURL, width: targetDisplay.width, height: targetDisplay.height, config: config)
            assetWriter = writer

            // 4. Initialize video compositor
            videoCompositor = VideoCompositor(
                width: targetDisplay.width,
                height: targetDisplay.height,
                cameraPosition: config.cameraPosition,
                cameraSize: config.cameraSize
            )

            // 5. Initialize annotation session and overlay
            let annotationSession = AnnotationSession()
            self.annotationSession = annotationSession
            let overlayWindow = AnnotationOverlayWindow(annotationSession: annotationSession)
            overlayWindow.attach(to: targetDisplay)
            overlayWindow.show()
            annotationOverlayWindow = overlayWindow
            self.objectWillChange.send()

            // 4. Start screen capture
            let screenCap = ScreenCaptureService()
            try await screenCap.start(display: targetDisplay, config: config)
            screenCap.onFrame = { [weak self] sampleBuffer, timestamp in
                Task { @MainActor in
                    self?.handleScreenFrame(sampleBuffer, timestamp: timestamp)
                }
            }
            screenCapture = screenCap

            // 5. Start camera capture (if enabled)
            if config.enableCamera {
                let camCap = CameraCaptureService()
                try await camCap.start()
                cameraCapture = camCap
                cameraSession = camCap.session
            }

            // 6. Start audio capture (if enabled)
            if config.enableMicrophone {
                let audioCap = AudioCaptureService()
                try await audioCap.start()
                audioCap.onAudioSample = { [weak self] sampleBuffer in
                    self?.handleAudioSample(sampleBuffer)
                }
                audioCapture = audioCap
            }

            // 7. Start duration timer
            startTime = Date()
            startTimer()

            state = .recording
            self.outputURL = outputURL

        } catch let recordingError as RecordingError {
            error = recordingError
            state = .idle
        } catch let unexpectedError {
            self.error = .captureFailed(unexpectedError)
            state = .idle
        }
    }

    /// Stop recording.
    func stop() async {
        state = .stopping

        // Stop all captures
        screenCapture?.stop()
        cameraCapture?.stop()
        audioCapture?.stop()

        // Stop timer
        timer?.invalidate()
        timer = nil

        // Finish writing
        await withCheckedContinuation { continuation in
            assetWriter?.finish { success, writerError in
                if success {
                    self.state = .stopped
                } else {
                    self.error = .writerFailed(writerError ?? RecordingError.unknown("Unknown writer error"))
                    self.state = .idle
                }
                continuation.resume()
            }
        }

        // Clean up
        annotationOverlayWindow?.hide()
        annotationOverlayWindow = nil
        annotationSession = nil
        cameraSession = nil
        screenCapture = nil
        cameraCapture = nil
        audioCapture = nil
        assetWriter = nil
        videoCompositor = nil
        startTime = nil
    }

    // MARK: - Frame Handling

    private func handleScreenFrame(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let assetWriter else { return }

        let compositedFrame: CVPixelBuffer
        if let compositor = videoCompositor {
            let webcamFrame = cameraCapture?.latestFrame().flatMap { CMSampleBufferGetImageBuffer($0) }
            let strokes = annotationSession?.strokes ?? []
            if let frame = compositor.composite(screenFrame: pixelBuffer, webcamFrame: webcamFrame, strokes: strokes) {
                compositedFrame = frame
            } else {
                compositedFrame = pixelBuffer
            }
        } else {
            compositedFrame = pixelBuffer
        }

        assetWriter.appendVideoFrame(compositedFrame, timestamp: timestamp)
    }

    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let assetWriter else { return }
        assetWriter.appendAudioSample(sampleBuffer)
    }

    // MARK: - Helpers

    private func generateOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let formatExt = config.outputFormat.rawValue
        let fileName = "RecordCourse-\(timestamp).\(formatExt)"
        let directory = config.outputDirectory
            ?? FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        return directory.appendingPathComponent(fileName)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let start = self.startTime {
                self.duration = Date().timeIntervalSince(start)
            }
        }
    }
}
