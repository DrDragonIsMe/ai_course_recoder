import Foundation

struct MagnifierConfig: OverlayConfig {
    var isEnabled: Bool
    var targetPoint: CGPoint
    var radius: CGFloat
    var scale: CGFloat
    var borderColorHex: String = "#FFFFFF"
}
