import Foundation
import CoreMedia
import CoreVideo

/// Helpers for working with CVPixelBuffer.
enum PixelBufferHelper {
    /// Copy an IOSurface-backed pixel buffer to a standard buffer that AVAssetWriter can accept.
    static func copyPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var copy: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            attrs as CFDictionary,
            &copy
        )

        guard status == kCVReturnSuccess, let dest = copy else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(dest, [])

        if let srcData = CVPixelBufferGetBaseAddress(pixelBuffer),
           let destData = CVPixelBufferGetBaseAddress(dest) {
            let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let destBytesPerRow = CVPixelBufferGetBytesPerRow(dest)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            for h in 0..<height {
                let srcRow = srcData.advanced(by: h * srcBytesPerRow)
                let destRow = destData.advanced(by: h * destBytesPerRow)
                destRow.copyMemory(from: srcRow, byteCount: srcBytesPerRow)
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(dest, [])

        return dest
    }

    /// Create an empty pixel buffer of the given size.
    static func createEmptyBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }
}
