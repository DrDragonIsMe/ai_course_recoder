import Foundation
import AppKit

struct CameraLayout: Codable, Equatable {
    var isVisible: Bool
    var region: LayoutRegion
    var borderWidth: CGFloat
    var borderColorHex: String
    var shadowRadius: CGFloat

    var borderColor: CGColor {
        NSColor(hex: borderColorHex)?.cgColor ?? CGColor.clear
    }
}
