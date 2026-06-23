import Foundation

struct StepAnnotation: Codable, Equatable {
    let id = UUID()
    var number: Int
    var text: String
    var targetPoint: CGPoint

    private enum CodingKeys: String, CodingKey {
        case number, text, targetPoint
    }
}

struct StepAnnotationConfig: OverlayConfig {
    var isEnabled: Bool
    var steps: [StepAnnotation]
    var colorHex: String = "#FF9500"
}
