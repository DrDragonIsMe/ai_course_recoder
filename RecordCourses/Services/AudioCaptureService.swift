import Foundation
import AVFoundation

/// Wraps AVCaptureSession to capture microphone audio.
final class AudioCaptureService: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.recordcourses.audio")

    /// Callback for each captured audio sample buffer.
    var onAudioSample: ((CMSampleBuffer) -> Void)?

    /// Format description of the active audio stream, available after start().
    private(set) var audioFormatDescription: CMFormatDescription?

    /// Discover available microphones.
    static func availableMicrophones() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices
    }

    /// Start audio capture.
    func start(microphone: AVCaptureDevice? = nil) async throws {
        let mics = Self.availableMicrophones()
        let selectedMic = microphone ?? mics.first
        guard let mic = selectedMic else {
            throw RecordingError.microphonePermissionDenied
        }

        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: mic)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }

        session.commitConfiguration()
        session.startRunning()
        audioFormatDescription = mic.activeFormat.formatDescription
    }

    /// Stop audio capture.
    func stop() {
        session.stopRunning()
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
extension AudioCaptureService: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onAudioSample?(sampleBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Late audio frames — expected under load
    }
}
