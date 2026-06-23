import Foundation

struct ChapterProgressConfig: OverlayConfig {
    var isEnabled: Bool
    var chapters: [ChapterMarker]
    var currentChapter: Int
    var barHeight: CGFloat = 4
    var activeColorHex: String = "#007AFF"
    var inactiveColorHex: String = "#E5E5EA"
}
