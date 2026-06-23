import Foundation
import CoreMedia
import CoreVideo
import CoreGraphics
import AppKit

/// Composites screen frames with webcam overlay and annotations.
final class VideoCompositor {
    private let width: Int
    private let height: Int
    private let cameraPosition: RecordingConfig.CameraPosition
    private let cameraSize: RecordingConfig.CameraSize

    init(width: Int, height: Int, cameraPosition: RecordingConfig.CameraPosition, cameraSize: RecordingConfig.CameraSize) {
        self.width = width
        self.height = height
        self.cameraPosition = cameraPosition
        self.cameraSize = cameraSize
    }

    /// Composite a screen frame with optional webcam overlay and annotation strokes.
    func composite(screenFrame: CVPixelBuffer, webcamFrame: CVPixelBuffer?, strokes: [Stroke]) -> CVPixelBuffer? {
        let shouldCompositeCamera = webcamFrame != nil
        let shouldCompositeAnnotations = !strokes.isEmpty

        // Fast path: nothing to overlay.
        if !shouldCompositeCamera && !shouldCompositeAnnotations {
            return screenFrame
        }

        // Copy the screen frame into a writable buffer we can draw on.
        guard let outputBuffer = PixelBufferHelper.copyPixelBuffer(screenFrame) else {
            return screenFrame
        }

        guard let context = createBitmapContext(pixelBuffer: outputBuffer) else {
            return screenFrame
        }

        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        // Flip Core Graphics coordinate system to match screen coordinates.
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -CGFloat(height))
        context.concatenate(transform)

        if let webcamFrame = webcamFrame {
            drawWebcam(webcamFrame, in: context)
        }

        if !strokes.isEmpty {
            drawStrokes(strokes, in: context)
        }

        return outputBuffer
    }

    // MARK: - Camera Overlay

    private func drawWebcam(_ webcamFrame: CVPixelBuffer, in context: CGContext) {
        CVPixelBufferLockBaseAddress(webcamFrame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(webcamFrame, .readOnly) }

        guard let webcamImage = cgImage(from: webcamFrame) else { return }

        let webcamRect = cameraRect(for: CGSize(width: width, height: height), webcamFrame: webcamFrame)

        // Draw rounded rect clipping path for the camera feed.
        let cornerRadius: CGFloat = min(webcamRect.width, webcamRect.height) * 0.08
        let path = NSBezierPath(roundedRect: webcamRect, xRadius: cornerRadius, yRadius: cornerRadius)

        context.saveGState()
        path.addClip()
        context.draw(webcamImage, in: webcamRect)

        // Subtle border.
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(2)
        context.stroke(webcamRect, width: 2)

        context.restoreGState()
    }

    private func cameraRect(for containerSize: CGSize, webcamFrame: CVPixelBuffer) -> CGRect {
        let webcamWidth = CVPixelBufferGetWidth(webcamFrame)
        let webcamHeight = CVPixelBufferGetHeight(webcamFrame)
        let aspectRatio = CGFloat(webcamWidth) / CGFloat(webcamHeight)
        let maxShortSide = min(containerSize.width, containerSize.height) * cameraSize.aspectRatioMultiplier
        var rect = CGRect.zero

        if aspectRatio >= 1 {
            rect.size.width = maxShortSide * aspectRatio
            rect.size.height = maxShortSide
        } else {
            rect.size.width = maxShortSide
            rect.size.height = maxShortSide / aspectRatio
        }

        let padding: CGFloat = 24
        switch cameraPosition {
        case .topLeft:
            rect.origin = CGPoint(x: padding, y: containerSize.height - rect.height - padding)
        case .topRight:
            rect.origin = CGPoint(x: containerSize.width - rect.width - padding, y: containerSize.height - rect.height - padding)
        case .bottomLeft:
            rect.origin = CGPoint(x: padding, y: padding)
        case .bottomRight:
            rect.origin = CGPoint(x: containerSize.width - rect.width - padding, y: padding)
        }

        return rect
    }

    // MARK: - Annotation Overlay

    private func drawStrokes(_ strokes: [Stroke], in context: CGContext) {
        for stroke in strokes {
            context.saveGState()
            context.setStrokeColor(stroke.color.cgColor)
            context.setLineWidth(stroke.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let points = stroke.points
            guard points.count > 1 else {
                context.restoreGState()
                continue
            }

            context.beginPath()
            context.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                context.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.strokePath()
            context.restoreGState()
        }
    }

    // MARK: - Helpers

    private func createBitmapContext(pixelBuffer: CVPixelBuffer) -> CGContext? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        return CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
    }

    private func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let dataProvider = CGDataProvider(dataInfo: nil, data: baseAddress, size: bytesPerRow * height, releaseData: { _, _, _ in }) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
