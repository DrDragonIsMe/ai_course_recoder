import Foundation
import CoreMedia
import CoreVideo
import CoreGraphics
import AppKit

/// Composites screen frames with webcam overlay, annotations, and layout-driven overlays.
final class VideoCompositor {
    let layout: RecordingLayout

    init(layout: RecordingLayout) {
        self.layout = layout
    }

    /// Composite a screen frame with optional webcam overlay, annotations, and layout-driven overlays.
    func composite(
        screenFrame: CVPixelBuffer,
        webcamFrame: CVPixelBuffer?,
        strokes: [Stroke],
        cursorPosition: CGPoint = .zero,
        cursorClickProgress: CGFloat = 0,
        recentKeys: [String] = [],
        subtitle: (primary: String, secondary: String?) = ("", nil),
        progress: CGFloat = 0
    ) -> CVPixelBuffer? {
        let containerSize = CGSize(
            width: CVPixelBufferGetWidth(screenFrame),
            height: CVPixelBufferGetHeight(screenFrame)
        )
        let containerRect = CGRect(origin: .zero, size: containerSize)

        guard let outputBuffer = PixelBufferHelper.copyPixelBuffer(screenFrame),
              let context = createBitmapContext(pixelBuffer: outputBuffer, size: containerSize) else {
            return screenFrame
        }

        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        // Make this bitmap context current so NSBezierPath-based clips/strokes
        // apply to it rather than to a nil current graphics context.
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        // Flip Core Graphics coordinate system to match screen coordinates.
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -containerSize.height)
        context.concatenate(transform)

        // Fill background.
        context.setFillColor(layout.backgroundColor)
        context.fill(containerRect)

        // Draw screen content into its layout region.
        drawScreenFrame(screenFrame, in: context, containerSize: containerSize)

        // Draw webcam into camera region.
        if let webcamFrame = webcamFrame, layout.cameraLayout.isVisible {
            drawWebcam(webcamFrame, in: context, containerSize: containerSize)
        }

        // Draw annotations.
        if !strokes.isEmpty {
            drawStrokes(strokes, in: context)
        }

        // Draw layout-driven overlays.
        drawOverlays(
            in: containerRect,
            context: context,
            screenFrame: screenFrame,
            cursorPosition: cursorPosition,
            cursorClickProgress: cursorClickProgress,
            recentKeys: recentKeys,
            subtitle: subtitle,
            progress: progress
        )

        return outputBuffer
    }

    // MARK: - Screen

    private func drawScreenFrame(_ screenFrame: CVPixelBuffer, in context: CGContext, containerSize: CGSize) {
        guard let image = cgImage(from: screenFrame) else { return }
        let rect = layout.screenRegion.rect(for: containerSize)
        drawImage(image, in: rect, cornerRadius: layout.screenRegion.cornerRadius, context: context)
    }

    // MARK: - Webcam

    private func drawWebcam(_ webcamFrame: CVPixelBuffer, in context: CGContext, containerSize: CGSize) {
        guard let image = cgImage(from: webcamFrame) else { return }
        let camera = layout.cameraLayout
        let rect = camera.region.rect(for: containerSize)

        context.saveGState()

        if camera.region.cornerRadius > 0 {
            let path = NSBezierPath(roundedRect: rect, xRadius: camera.region.cornerRadius, yRadius: camera.region.cornerRadius)
            path.addClip()
        }

        if camera.shadowRadius > 0 {
            context.setShadow(offset: CGSize(width: 0, height: -4), blur: camera.shadowRadius, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        }

        context.draw(image, in: rect)

        if camera.borderWidth > 0 {
            context.setStrokeColor(camera.borderColor)
            context.setLineWidth(camera.borderWidth)
            if camera.region.cornerRadius > 0 {
                let path = NSBezierPath(roundedRect: rect, xRadius: camera.region.cornerRadius, yRadius: camera.region.cornerRadius)
                path.stroke()
            } else {
                context.stroke(rect)
            }
        }

        context.restoreGState()
    }

    // MARK: - Annotations

    private func drawStrokes(_ strokes: [Stroke], in context: CGContext) {
        for stroke in strokes {
            drawStroke(stroke, in: context)
        }
    }

    private func drawStroke(_ stroke: Stroke, in context: CGContext) {
        let points = stroke.points
        guard points.count > 1 else { return }

        context.saveGState()
        context.setStrokeColor(stroke.color.cgColor)
        context.setLineWidth(stroke.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch stroke.tool {
        case .pen, .eraser:
            context.beginPath()
            context.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                context.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            if stroke.tool == .eraser {
                context.setBlendMode(.clear)
            }
            context.strokePath()

        case .arrow:
            drawArrow(points: points, in: context)

        case .rectangle:
            guard let first = points.first, let last = points.last else { break }
            let rect = CGRect(origin: first, size: CGSize(width: last.x - first.x, height: last.y - first.y))
            context.stroke(rect)

        case .circle:
            guard let first = points.first, let last = points.last else { break }
            let rect = CGRect(origin: first, size: CGSize(width: last.x - first.x, height: last.y - first.y))
            context.strokeEllipse(in: rect)

        case .text, .cursorHighlight:
            break
        }

        context.restoreGState()
    }

    private func drawArrow(points: [NSPoint], in context: CGContext) {
        guard let start = points.first, let end = points.last, start != end else { return }

        context.beginPath()
        context.move(to: CGPoint(x: start.x, y: start.y))
        context.addLine(to: CGPoint(x: end.x, y: end.y))
        context.strokePath()

        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        let angle = atan2(end.y - start.y, end.x - start.x)

        context.beginPath()
        context.move(to: CGPoint(x: end.x, y: end.y))
        context.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        ))
        context.move(to: CGPoint(x: end.x, y: end.y))
        context.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        ))
        context.strokePath()
    }

    // MARK: - Overlays

    private func drawOverlays(
        in containerRect: CGRect,
        context: CGContext,
        screenFrame: CVPixelBuffer,
        cursorPosition: CGPoint,
        cursorClickProgress: CGFloat,
        recentKeys: [String],
        subtitle: (primary: String, secondary: String?),
        progress: CGFloat
    ) {
        let sourceImage = cgImage(from: screenFrame)

        StepAnnotationRenderer(config: layout.stepAnnotation)
            .draw(in: containerRect, context: context)

        CursorHighlightRenderer(
            config: layout.cursorHighlight,
            position: cursorPosition,
            clickProgress: cursorClickProgress
        ).draw(in: containerRect, context: context)

        KeyPressRenderer(config: layout.keyPressOverlay, recentKeys: recentKeys)
            .draw(in: containerRect, context: context)

        MagnifierRenderer(config: layout.magnifier, sourceImage: sourceImage, cursorPosition: cursorPosition)
            .draw(in: containerRect, context: context)

        SubtitleRenderer(config: layout.subtitle, primary: subtitle.primary, secondary: subtitle.secondary)
            .draw(in: containerRect, context: context)

        ChapterProgressRenderer(config: layout.chapterProgress, progress: progress)
            .draw(in: containerRect, context: context)

        WatermarkRenderer(config: layout.watermark)
            .draw(in: containerRect, context: context)
    }

    // MARK: - Helpers

    private func drawImage(_ image: CGImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext) {
        context.saveGState()
        if cornerRadius > 0 {
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.addClip()
        }
        context.draw(image, in: rect)
        context.restoreGState()
    }

    private func createBitmapContext(pixelBuffer: CVPixelBuffer, size: CGSize) -> CGContext? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        return CGContext(
            data: baseAddress,
            width: Int(size.width),
            height: Int(size.height),
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
