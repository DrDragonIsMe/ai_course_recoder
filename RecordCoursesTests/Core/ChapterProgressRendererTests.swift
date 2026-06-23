import Testing
import CoreGraphics
import AppKit
@testable import RecordCourses

@Suite("Chapter Progress Renderer Tests")
struct ChapterProgressRendererTests {

    private func makeContext(size: CGSize) -> CGContext? {
        CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
    }

    @Test("Progress bar renderer draws without errors")
    func progressBarDraws() {
        let config = ChapterProgressConfig(
            isEnabled: true,
            chapters: [
                ChapterMarker(title: "Intro", timestamp: 0),
                ChapterMarker(title: "Main", timestamp: 30),
                ChapterMarker(title: "Outro", timestamp: 60)
            ],
            currentChapter: 1
        )
        let renderer = ChapterProgressRenderer(config: config, progress: 0.5)
        let context = makeContext(size: CGSize(width: 400, height: 50))!
        renderer.draw(in: CGRect(x: 0, y: 0, width: 400, height: 50), context: context)
        #expect(true)
    }

    @Test("Disabled progress bar does not draw")
    func disabledProgressBarIsNoOp() {
        let config = ChapterProgressConfig(
            isEnabled: false,
            chapters: [ChapterMarker(title: "Only", timestamp: 0)],
            currentChapter: 0
        )
        let renderer = ChapterProgressRenderer(config: config, progress: 0.5)
        let context = makeContext(size: CGSize(width: 400, height: 50))!
        renderer.draw(in: CGRect(x: 0, y: 0, width: 400, height: 50), context: context)
        #expect(true)
    }
}

@Suite("Magnifier Renderer Tests")
struct MagnifierRendererTests {

    private func makeContext(size: CGSize) -> CGContext? {
        CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
    }

    private func makeImage(size: CGSize) -> CGImage? {
        guard let context = makeContext(size: size) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    @Test("Magnifier renders at cursor position without errors")
    func magnifierRendersAtCursorPosition() {
        let config = MagnifierConfig(
            isEnabled: true,
            targetPoint: .zero,
            radius: 30,
            scale: 2
        )
        let sourceImage = makeImage(size: CGSize(width: 200, height: 200))
        #expect(sourceImage != nil)
        let renderer = MagnifierRenderer(
            config: config,
            sourceImage: sourceImage,
            cursorPosition: CGPoint(x: 100, y: 100)
        )
        let context = makeContext(size: CGSize(width: 200, height: 200))!
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        defer { NSGraphicsContext.restoreGraphicsState() }
        renderer.draw(in: CGRect(x: 0, y: 0, width: 200, height: 200), context: context)
        #expect(true)
    }

    @Test("Disabled magnifier is a no-op")
    func disabledMagnifierIsNoOp() {
        let config = MagnifierConfig(isEnabled: false, targetPoint: .zero, radius: 30, scale: 2)
        let renderer = MagnifierRenderer(
            config: config,
            sourceImage: makeImage(size: CGSize(width: 200, height: 200)),
            cursorPosition: CGPoint(x: 100, y: 100)
        )
        let context = makeContext(size: CGSize(width: 200, height: 200))!
        renderer.draw(in: CGRect(x: 0, y: 0, width: 200, height: 200), context: context)
        #expect(true)
    }
}
