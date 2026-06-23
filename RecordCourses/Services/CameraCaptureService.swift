import Foundation
import AVFoundation

/// Wraps AVCaptureSession to capture webcam frames.
final class CameraCaptureService: NSObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.recordcourses.camera")
    private var device: AVCaptureDevice?

    /// Latest captured frame (kept in a small ring buffer).
    private var latestFrameBuffer: CMSampleBuffer?
    private let frameLock = NSLock()

    /// Callback for each captured camera frame.
    var onFrame: ((CMSampleBuffer) -> Void)?

    /// Discover available cameras.
    static func availableCameras() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices
    }

    /// Start camera capture.
    func start(camera: AVCaptureDevice? = nil) async throws {
        let cameras = Self.availableCameras()
        let selectedCamera = camera ?? cameras.first
        guard let camera = selectedCamera else {
            throw RecordingError.cameraPermissionDenied
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        self.device = camera
        session.commitConfiguration()
        session.startRunning()
    }

    /// Stop camera capture.
    func stop() {
        session.stopRunning()
        device = nil
    }

    /// Get the latest captured frame.
    func latestFrame() -> CMSampleBuffer? {
        frameLock.lock()
        defer { frameLock.unlock() }
        return latestFrameBuffer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameLock.lock()
        latestFrameBuffer = sampleBuffer
        frameLock.unlock()

        onFrame?(sampleBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Late frames are dropped — this is expected behavior
    }
}
