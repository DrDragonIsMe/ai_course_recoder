import Foundation
import AVFoundation

/// Wraps AVAssetWriter to write video and audio to disk in real time.
final class RecordingAssetWriter {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var isReady = false

    /// Start writing to the given URL.
    /// Pass the microphone's `CMFormatDescription` so audio settings match the captured format.
    func start(
        url: URL,
        width: Int,
        height: Int,
        config: RecordingConfig,
        audioFormatDescription: CMFormatDescription? = nil
    ) throws {
        // Remove existing file
        if FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.removeItem(at: url)
        }

        writer = try AVAssetWriter(url: url, fileType: config.outputFormat.fileType)

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

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        if let videoInput = videoInput, writer?.canAdd(videoInput) == true {
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

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channelCount,
                AVEncoderBitRateKey: 128000,
            ]

            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings, sourceFormatHint: audioFormatDescription)
            input.expectsMediaDataInRealTime = true

            if writer?.canAdd(input) == true {
                writer?.add(input)
                audioInput = input
            }
        }

        guard writer?.startWriting() == true else {
            throw RecordingError.writerFailed(writer?.error ?? RecordingError.unknown("Asset writer failed to start"))
        }
        isReady = false
    }

    /// Append a video frame.
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> Bool {
        guard let writer, writer.status == .writing,
              let videoInput, let videoAdaptor else { return false }

        if !isReady {
            writer.startSession(atSourceTime: timestamp)
            isReady = true
        }

        guard videoInput.isReadyForMoreMediaData else { return false }
        return videoAdaptor.append(pixelBuffer, withPresentationTime: timestamp)
    }

    /// Append an audio sample buffer.
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let writer, writer.status == .writing,
              let audioInput else { return false }

        if !isReady {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: timestamp)
            isReady = true
        }

        guard audioInput.isReadyForMoreMediaData else { return false }
        return audioInput.append(sampleBuffer)
    }

    /// Finish writing and finalize the file.
    func finish(completion: @escaping (Bool, Error?) -> Void) {
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        writer?.finishWriting {
            let success = self.writer?.status == .completed
            let error = self.writer?.status == .failed ? self.writer?.error : nil
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
