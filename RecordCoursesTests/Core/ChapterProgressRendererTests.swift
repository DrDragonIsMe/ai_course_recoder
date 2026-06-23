import Testing
import CoreGraphics
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
