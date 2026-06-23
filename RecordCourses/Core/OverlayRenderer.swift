import Foundation
import CoreGraphics

/// Renders an overlay into a Core Graphics context.
protocol OverlayRenderer {
    associatedtype Config: OverlayConfig
    var config: Config { get }
    func draw(in rect: CGRect, context: CGContext)
}
