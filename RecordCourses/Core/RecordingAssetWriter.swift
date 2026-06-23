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
    func start(url: URL, width: Int, height: Int, config: RecordingConfig) throws {
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
                AVVideoQualityKey: 0.85,
            ] as [String: Any],
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        if let videoInput = videoInput, writer?.canAdd(videoInput) == true {
            writer?.add(videoInput)
        }

        // Pixel buffer adaptor
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        videoAdaptor = adaptor

        // Audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        if let audioInput = audioInput, writer?.canAdd(audioInput) == true {
            writer?.add(audioInput)
        }

        writer?.startWriting()
        isReady = false
    }

    /// Append a video frame.
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> Bool {
        guard let writer, writer.status == .writing,
              let videoInput, videoInput.isReadyForMoreMediaData,
              let videoAdaptor else { return false }

        if !isReady {
            writer.startSession(atSourceTime: timestamp)
            isReady = true
        }

        return videoAdaptor.append(pixelBuffer, withPresentationTime: timestamp)
    }

    /// Append an audio sample buffer.
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let writer, writer.status == .writing,
              let audioInput, audioInput.isReadyForMoreMediaData else { return false }

        if !isReady {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: timestamp)
            isReady = true
        }

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
