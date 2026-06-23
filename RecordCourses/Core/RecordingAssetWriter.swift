import Foundation
import AVFoundation
import os.log

/// Wraps AVAssetWriter to write video and audio to disk in real time.
final class RecordingAssetWriter {
    private static let logger = Logger(subsystem: "com.qijiayoudao.RecordCourses", category: "RecordingAssetWriter")
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var isReady = false

    private static func errorDescription(_ error: Error?) -> String {
        guard let error else { return "nil" }
        let nsError = error as NSError
        return "\(nsError.domain)(\(nsError.code)) \(error.localizedDescription)"
    }

    /// Start writing to the given URL.
    /// Pass the microphone's `CMFormatDescription` so audio settings match the captured format.
    func start(
        url: URL,
        width: Int,
        height: Int,
        config: RecordingConfig,
        audioFormatDescription: CMFormatDescription? = nil
    ) throws {
        Self.logger.info("Starting writer at \(url.path) \(width)x\(height) codec=\(String(describing: config.videoCodec)) format=\(String(describing: config.outputFormat))")

        // Remove existing file
        if FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.removeItem(at: url)
        }

        let fileType = config.outputFormat.fileType
        writer = try AVAssetWriter(url: url, fileType: fileType)

        // Video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: config.videoCodec.avCodec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * config.quality.bitrateMultiplier,
                AVVideoMaxKeyFrameIntervalKey: config.fps * 2,
            ] as [String: Any],
        ]

        Self.logger.debug("Video settings: \(videoSettings)")

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        if let videoInput = videoInput {
            guard writer?.canAdd(videoInput) == true else {
                let error = writer?.error ?? RecordingError.unknown("Cannot add video input")
                Self.logger.error("Cannot add video input: \(Self.errorDescription(error), privacy: .public)")
                throw RecordingError.writerFailed(error)
            }
            writer?.add(videoInput)
        }

        // Pixel buffer adaptor
        guard let videoInput = videoInput else {
            throw RecordingError.unknown("Could not create video writer input")
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        videoAdaptor = adaptor

        // Audio input (only if microphone is enabled and we have a format description)
        if config.enableMicrophone, let audioFormatDescription = audioFormatDescription {
            var channelCount: Int = 2
            var sampleRate: Double = 48000
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription) {
                channelCount = Int(asbd.pointee.mChannelsPerFrame)
                sampleRate = asbd.pointee.mSampleRate
            }

            Self.logger.info("Audio format: \(sampleRate) Hz, \(channelCount) ch")

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channelCount,
                AVEncoderBitRateKey: 128000,
            ]

            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings, sourceFormatHint: audioFormatDescription)
            input.expectsMediaDataInRealTime = true

            guard writer?.canAdd(input) == true else {
                let error = writer?.error ?? RecordingError.unknown("Cannot add audio input")
                Self.logger.error("Cannot add audio input: \(Self.errorDescription(error), privacy: .public)")
                throw RecordingError.writerFailed(error)
            }
            writer?.add(input)
            audioInput = input
        } else {
            let hasAudioFormat = audioFormatDescription != nil ? "yes" : "no"
            Self.logger.info("No audio input (microphone=\(config.enableMicrophone), format=\(hasAudioFormat))")
        }

        // startWriting() is synchronous: on success the writer is immediately in
        // the .writing state. Do NOT poll with Thread.sleep here — this method runs
        // on the @MainActor (via RecordingPipeline.start), and blocking the main
        // actor thread wedges SwiftUI's cooperative main executor, which crashes
        // later button dispatch in MainActor.assumeIsolated (EXC_BAD_ACCESS in
        // swift_getObjectType). A single non-blocking check is sufficient.
        guard writer?.startWriting() == true, writer?.status == .writing else {
            let error = writer?.error ?? RecordingError.unknown("Asset writer failed to start writing")
            Self.logger.error("startWriting failed: \(Self.errorDescription(error), privacy: .public)")
            throw RecordingError.writerFailed(error)
        }

        Self.logger.info("Writer started successfully")
        // Intentionally do NOT set isReady = true here. isReady tracks whether the
        // writer *session* has been started via startSession(atSourceTime:), which
        // must happen lazily on the first appended video frame so the session
        // anchor matches the first captured timestamp. Setting it now would skip
        // startSession and produce an empty / unplayable file.
    }

    /// Append a video frame.
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> Bool {
        guard let writer, writer.status == .writing,
              let videoInput, let videoAdaptor else {
            if let writer, writer.status == .failed {
                Self.logger.error("Video append skipped: writer failed: \(Self.errorDescription(writer.error), privacy: .public)")
            }
            return false
        }

        if !isReady {
            writer.startSession(atSourceTime: timestamp)
            Self.logger.info("Started writer session at video time \(timestamp.seconds)")
            isReady = true
        }

        guard videoInput.isReadyForMoreMediaData else { return false }
        let appended = videoAdaptor.append(pixelBuffer, withPresentationTime: timestamp)
        if !appended {
            Self.logger.error("Failed to append video frame: \(Self.errorDescription(writer.error), privacy: .public)")
        }
        return appended
    }

    /// Append an audio sample buffer.
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let writer, writer.status == .writing,
              let audioInput else {
            if let writer, writer.status == .failed {
                Self.logger.error("Audio append skipped: writer failed: \(Self.errorDescription(writer.error), privacy: .public)")
            }
            return false
        }

        guard isReady else {
            Self.logger.debug("Audio sample arrived before video session started; dropping")
            return false
        }

        guard audioInput.isReadyForMoreMediaData else { return false }
        let appended = audioInput.append(sampleBuffer)
        if !appended {
            Self.logger.error("Failed to append audio sample: \(Self.errorDescription(writer.error), privacy: .public)")
        }
        return appended
    }

    /// Finish writing and finalize the file.
    func finish(completion: @escaping (Bool, Error?) -> Void) {
        Self.logger.info("Finishing writer (status: \(String(describing: self.writer?.status.rawValue)))")
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        writer?.finishWriting {
            let success = self.writer?.status == .completed
            let error = self.writer?.status == .failed ? self.writer?.error : nil
            if let error {
                Self.logger.error("Writer finished with error: \(Self.errorDescription(error), privacy: .public)")
            } else {
                Self.logger.info("Writer finished successfully")
            }
            completion(success, error)
        }
    }

    /// Cancel writing.
    func cancel() {
        writer?.cancelWriting()
        isReady = false
    }

    /// Current writer status.
    var status: AVAssetWriter.Status {
        writer?.status ?? .unknown
    }
}
