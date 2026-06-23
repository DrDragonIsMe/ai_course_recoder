import Foundation

struct SubtitleConfig: OverlayConfig {
    var isEnabled: Bool
    var bilingual: Bool
    var fontSize: CGFloat = 20
    var textColorHex: String = "#FFFFFF"
    var outlineColorHex: String = "#000000"
}
