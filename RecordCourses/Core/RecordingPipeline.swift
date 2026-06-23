import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit
import Combine
import os.log

/// Orchestrates the full recording lifecycle: screen + camera + audio → file.
@MainActor
final class RecordingPipeline: ObservableObject {
    private static let logger = Logger(subsystem: "com.qijiayoudao.RecordCourses", category: "RecordingPipeline")

    @Published var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var error: RecordingError?
    @Published var outputURL: URL?

    /// Active annotation session while recording. Exposed so the UI can show the annotation toolbar.
    private(set) var annotationSession: AnnotationSession?

    /// Annotation overlay window. Exposed so the UI can toggle drawing mode.
    private(set) var annotationOverlayWindow: AnnotationOverlayWindow?

    /// Camera capture session, exposed for live preview.
    private(set) var cameraSession: AVCaptureSession?

    private var screenCapture: ScreenCaptureService?
    private var cameraCapture: CameraCaptureService?
    private var audioCapture: AudioCaptureService?
    private var assetWriter: RecordingAssetWriter?
    private var videoCompositor: VideoCompositor?

    private var startTime: Date?
    private var timer: Timer?
    private var config: RecordingConfig = .saved

    private var cursorTracker: CursorTracker?
    private var keyPressMonitor: KeyPressMonitor?
    private var cancellables = Set<AnyCancellable>()

    private var cursorPosition: CGPoint = .zero
    private var cursorClickProgress: CGFloat = 0
    private var recentKeys: [String] = []
    private var currentSubtitle: (primary: String, secondary: String?) = ("", nil)
    private var recordingProgress: CGFloat = 0
    private var frameCount = 0
    private var audioCount = 0
    private var firstFrameWatchdog: Task<Void, Never>?

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

            // 3. Initialize video compositor
            videoCompositor = VideoCompositor(layout: config.layout)

            // 4. Initialize annotation session and overlay
            let annotationSession = AnnotationSession()
            self.annotationSession = annotationSession
            let overlayWindow = AnnotationOverlayWindow(annotationSession: annotationSession)
            overlayWindow.attach(to: targetDisplay)
            overlayWindow.show()
            annotationOverlayWindow = overlayWindow
            self.objectWillChange.send()

            // 5. Start camera capture (if enabled)
            if config.enableCamera {
                let camCap = CameraCaptureService()
                try await camCap.start()
                cameraCapture = camCap
                cameraSession = camCap.session
            }

            // 6. Start audio capture (if enabled) so we know its format before creating the writer
            var audioFormatDescription: CMFormatDescription?
            if config.enableMicrophone {
                let audioCap = AudioCaptureService()
                do {
                    try await audioCap.start()
                    audioFormatDescription = audioCap.audioFormatDescription
                    audioCap.onAudioSample = { [weak self] sampleBuffer in
                        Task { @MainActor in
                            self?.handleAudioSample(sampleBuffer)
                        }
                    }
                    audioCapture = audioCap
                } catch {
                    // If we can't start audio capture, continue without audio
                    Self.logger.warning("Failed to start audio capture: \(error.localizedDescription)")
                    // Continue with recording but without audio
                }
            }

            // 7. Initialize asset writer (after camera/audio so audio format is known)
            let writer = RecordingAssetWriter()
            do {
                try writer.start(
                    url: outputURL,
                    width: targetDisplay.width,
                    height: targetDisplay.height,
                    config: config,
                    audioFormatDescription: audioFormatDescription
                )
                assetWriter = writer
            } catch {
                // If we can't initialize the writer, throw an appropriate error
                Self.logger.error("Failed to initialize asset writer: \(error.localizedDescription)")
                throw RecordingError.writerFailed(error)
            }

            // 8. Start screen capture
            let screenCap = ScreenCaptureService()
            try await screenCap.start(display: targetDisplay, config: config)
            screenCap.onFrame = { [weak self] sampleBuffer, timestamp in
                Task { @MainActor in
                    self?.handleScreenFrame(sampleBuffer, timestamp: timestamp)
                }
            }
            screenCapture = screenCap

            // 9. Start overlay state trackers
            startOverlayTrackers()

            // 10. Start duration timer
            startTime = Date()
            startTimer()

            state = .recording
            self.outputURL = outputURL

            // Watchdog: if no video frame arrives within a few seconds of
            // recording start, the screen-capture permission is almost certainly
            // denied or stale (common with adhoc-signed debug builds — macOS
            // invalidates the TCC grant when the signature changes on rebuild).
            // SCStream.startCapture() returns OK in that state but never calls
            // didOutput, so without this check we'd silently record an empty
            // video and drop all audio forever. Surface a clear error instead.
            startFirstFrameWatchdog()

        } catch let recordingError as RecordingError {
            error = recordingError
            state = .idle
        } catch let unexpectedError {
            self.error = .captureFailed(unexpectedError)
            state = .idle
        }
    }

    /// Toggle annotation drawing mode on the overlay window.
    func toggleAnnotationDrawingMode() {
        annotationOverlayWindow?.toggleDrawingMode()
    }

    /// Stop recording.
    func stop() async {
        state = .stopping

        // Cancel the first-frame watchdog if still pending.
        firstFrameWatchdog?.cancel()
        firstFrameWatchdog = nil

        // Stop all captures
        screenCapture?.stop()
        cameraCapture?.stop()
        audioCapture?.stop()

        // Stop overlay trackers
        cursorTracker?.stop()
        cursorTracker = nil
        keyPressMonitor?.stop()
        keyPressMonitor = nil
        cancellables.removeAll()

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
              let assetWriter else {
            NSLog("Pipeline handleScreenFrame early return (no pixelBuffer or writer)")
            return
        }

        frameCount += 1
        if frameCount == 1 {
            // First real video frame arrived — capture permission is working.
            // Cancel the watchdog that would otherwise flag a silent failure.
            firstFrameWatchdog?.cancel()
            firstFrameWatchdog = nil
            Self.logger.info("First video frame received at frame #1")
        }
        if frameCount == 1 || frameCount % 30 == 0 {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let statusRaw = assetWriter.status.rawValue
            NSLog("Pipeline frame #%d %dx%d writerStatus=%ld", frameCount, width, height, statusRaw)
        }

        let compositedFrame: CVPixelBuffer
        if let compositor = videoCompositor {
            let webcamFrame = cameraCapture?.latestFrame().flatMap { CMSampleBufferGetImageBuffer($0) }
            let strokes = annotationSession?.strokes ?? []
            if let start = startTime {
                let elapsed = Date().timeIntervalSince(start)
                recordingProgress = CGFloat(min(elapsed / 60.0, 1.0))
                updateSubtitle(for: elapsed)
            }
            if let frame = compositor.composite(
                screenFrame: pixelBuffer,
                webcamFrame: webcamFrame,
                strokes: strokes,
                cursorPosition: cursorPosition,
                cursorClickProgress: cursorClickProgress,
                recentKeys: recentKeys,
                subtitle: currentSubtitle,
                progress: recordingProgress
            ) {
                compositedFrame = frame
            } else {
                NSLog("Pipeline compositor returned nil at frame #%d", frameCount)
                compositedFrame = pixelBuffer
            }
        } else {
            compositedFrame = pixelBuffer
        }

        if !assetWriter.appendVideoFrame(compositedFrame, timestamp: timestamp) {
            NSLog("Pipeline appendVideoFrame failed at frame #%d", frameCount)
        }
    }

    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let assetWriter else {
            NSLog("Pipeline handleAudioSample early return (no writer)")
            return
        }

        audioCount += 1
        if audioCount == 1 || audioCount % 50 == 0 {
            NSLog("Pipeline audio #%d writerStatus=%ld", audioCount, assetWriter.status.rawValue)
        }

        if !assetWriter.appendAudioSample(sampleBuffer) {
            NSLog("Pipeline appendAudioSample failed at audio #%d", audioCount)
        }
    }

    private func updateSubtitle(for elapsed: TimeInterval) {
        guard config.layout.subtitle.isEnabled else {
            currentSubtitle = ("", nil)
            return
        }
        currentSubtitle = SubtitleLoader.subtitle(
            for: elapsed,
            entries: config.layout.subtitle.entries,
            bilingual: config.layout.subtitle.bilingual
        )
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

    /// Watchdog: if no video frame arrives within the grace period, treat the
    /// screen-capture permission as denied/stale and stop with a clear error.
    private func startFirstFrameWatchdog() {
        firstFrameWatchdog?.cancel()
        let grace: UInt64 = 4_000_000_000 // 4 seconds
        firstFrameWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: grace)
            guard let self, !Task.isCancelled else { return }
            guard self.frameCount == 0 else { return }
            Self.logger.error("No video frames within grace period — screen capture permission is denied or stale")
            self.error = .screenCapturePermissionDenied
            self.state = .idle
            // Tear down the partial recording so the UI resets cleanly.
            self.screenCapture?.stop()
            self.audioCapture?.stop()
            self.cameraCapture?.stop()
            self.cursorTracker?.stop()
            self.cursorTracker = nil
            self.keyPressMonitor?.stop()
            self.keyPressMonitor = nil
            self.cancellables.removeAll()
            self.timer?.invalidate()
            self.timer = nil
            self.firstFrameWatchdog = nil
        }
    }

    private func startOverlayTrackers() {
        let tracker = CursorTracker()
        tracker.start()
        tracker.$position
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in self?.cursorPosition = position }
            .store(in: &cancellables)
        tracker.$clickProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in self?.cursorClickProgress = progress }
            .store(in: &cancellables)
        cursorTracker = tracker

        let monitor = KeyPressMonitor()
        monitor.start()
        monitor.$recentKeys
            .receive(on: DispatchQueue.main)
            .sink { [weak self] keys in self?.recentKeys = keys }
            .store(in: &cancellables)
        keyPressMonitor = monitor
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let start = self.startTime {
                    self.duration = Date().timeIntervalSince(start)
                }
            }
        }
    }
}
