import Foundation

struct CursorHighlightConfig: OverlayConfig {
    var isEnabled: Bool
    var colorHex: String
    var radius: CGFloat
    var showClicks: Bool
    var clickRippleDuration: TimeInterval = 0.4
}
