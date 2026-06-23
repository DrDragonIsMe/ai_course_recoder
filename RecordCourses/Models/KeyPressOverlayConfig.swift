import Foundation

struct KeyPressOverlayConfig: OverlayConfig {
    enum Position: String, Codable, CaseIterable {
        case bottomLeft, bottomRight
    }

    var isEnabled: Bool
    var position: Position
    var maxKeys: Int
    var backgroundColorHex: String = "#000000"
    var textColorHex: String = "#FFFFFF"
}
