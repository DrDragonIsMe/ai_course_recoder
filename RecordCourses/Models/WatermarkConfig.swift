import Foundation

struct WatermarkConfig: OverlayConfig {
    enum Position: String, Codable, CaseIterable {
        case bottomLeft, bottomRight
    }

    var isEnabled: Bool
    var logoText: String
    var instructorName: String
    var position: Position
    var textColorHex: String = "#000000"
}
