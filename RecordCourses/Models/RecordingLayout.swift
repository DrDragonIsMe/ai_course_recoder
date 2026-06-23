import Foundation
import AppKit

struct RecordingLayout: Codable, Equatable {
    var name: String
    var screenRegion: LayoutRegion
    var cameraLayout: CameraLayout
    var backgroundColorHex: String

    var watermark: WatermarkConfig
    var cursorHighlight: CursorHighlightConfig
    var keyPressOverlay: KeyPressOverlayConfig
    var magnifier: MagnifierConfig
    var stepAnnotation: StepAnnotationConfig
    var subtitle: SubtitleConfig
    var chapterProgress: ChapterProgressConfig

    var backgroundColor: CGColor {
        NSColor(hex: backgroundColorHex)?.cgColor ?? NSColor.black.cgColor
    }

    init(
        name: String,
        screenRegion: LayoutRegion,
        cameraLayout: CameraLayout,
        backgroundColorHex: String,
        watermark: WatermarkConfig = WatermarkConfig(isEnabled: false, logoText: "", instructorName: "", position: .bottomRight),
        cursorHighlight: CursorHighlightConfig = CursorHighlightConfig(isEnabled: false, colorHex: "#FF0000", radius: 20, showClicks: true),
        keyPressOverlay: KeyPressOverlayConfig = KeyPressOverlayConfig(isEnabled: false, position: .bottomRight, maxKeys: 5),
        magnifier: MagnifierConfig = MagnifierConfig(isEnabled: false, targetPoint: .zero, radius: 60, scale: 2),
        stepAnnotation: StepAnnotationConfig = StepAnnotationConfig(isEnabled: false, steps: []),
        subtitle: SubtitleConfig = SubtitleConfig(isEnabled: false, bilingual: false, entries: []),
        chapterProgress: ChapterProgressConfig = ChapterProgressConfig(isEnabled: false, chapters: [], currentChapter: 0)
    ) {
        self.name = name
        self.screenRegion = screenRegion
        self.cameraLayout = cameraLayout
        self.backgroundColorHex = backgroundColorHex
        self.watermark = watermark
        self.cursorHighlight = cursorHighlight
        self.keyPressOverlay = keyPressOverlay
        self.magnifier = magnifier
        self.stepAnnotation = stepAnnotation
        self.subtitle = subtitle
        self.chapterProgress = chapterProgress
    }

    static func fullScreen() -> RecordingLayout {
        RecordingLayout(
            name: "Full Screen",
            screenRegion: LayoutRegion(anchor: .full, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), padding: 0, cornerRadius: 0),
            cameraLayout: CameraLayout(isVisible: false, region: LayoutRegion(anchor: .bottomRight, normalizedRect: .zero, padding: 0, cornerRadius: 0), borderWidth: 0, borderColorHex: "#000000", shadowRadius: 0),
            backgroundColorHex: "#000000"
        )
    }

    static func presenterRight(screenSize: CGSize) -> RecordingLayout {
        RecordingLayout(
            name: "Presenter Right",
            screenRegion: LayoutRegion(anchor: .topLeft, normalizedRect: CGRect(x: 0, y: 0, width: 0.65, height: 1), padding: 16, cornerRadius: 12),
            cameraLayout: CameraLayout(
                isVisible: true,
                region: LayoutRegion(anchor: .topRight, normalizedRect: CGRect(x: 0.65, y: 0, width: 0.35, height: 1), padding: 16, cornerRadius: 12),
                borderWidth: 0,
                borderColorHex: "#FFFFFF",
                shadowRadius: 0
            ),
            backgroundColorHex: "#FFFFFF"
        )
    }

    static func presenterLeft(screenSize: CGSize) -> RecordingLayout {
        RecordingLayout(
            name: "Presenter Left",
            screenRegion: LayoutRegion(anchor: .topRight, normalizedRect: CGRect(x: 0.35, y: 0, width: 0.65, height: 1), padding: 16, cornerRadius: 12),
            cameraLayout: CameraLayout(
                isVisible: true,
                region: LayoutRegion(anchor: .topLeft, normalizedRect: CGRect(x: 0, y: 0, width: 0.35, height: 1), padding: 16, cornerRadius: 12),
                borderWidth: 0,
                borderColorHex: "#FFFFFF",
                shadowRadius: 0
            ),
            backgroundColorHex: "#FFFFFF"
        )
    }

    static func cornerPIP() -> RecordingLayout {
        RecordingLayout(
            name: "Corner PIP",
            screenRegion: LayoutRegion(anchor: .full, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), padding: 0, cornerRadius: 0),
            cameraLayout: CameraLayout(
                isVisible: true,
                region: LayoutRegion(anchor: .bottomRight, normalizedRect: CGRect(x: 0.78, y: 0.72, width: 0.20, height: 0.25), padding: 16, cornerRadius: 12),
                borderWidth: 3,
                borderColorHex: "#FFFFFF",
                shadowRadius: 12
            ),
            backgroundColorHex: "#000000"
        )
    }

    static func softwareDemo() -> RecordingLayout {
        RecordingLayout(
            name: "Software Demo",
            screenRegion: LayoutRegion(anchor: .full, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), padding: 0, cornerRadius: 0),
            cameraLayout: CameraLayout(isVisible: false, region: LayoutRegion(anchor: .bottomRight, normalizedRect: .zero, padding: 0, cornerRadius: 0), borderWidth: 0, borderColorHex: "#000000", shadowRadius: 0),
            backgroundColorHex: "#000000"
        )
    }

    static let allPresets: [RecordingLayout] = [
        .fullScreen(),
        .cornerPIP(),
        .presenterLeft(screenSize: CGSize(width: 1920, height: 1080)),
        .presenterRight(screenSize: CGSize(width: 1920, height: 1080)),
        .softwareDemo()
    ]
}
