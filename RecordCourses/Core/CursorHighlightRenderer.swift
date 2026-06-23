import Foundation
import CoreGraphics
import AppKit

struct CursorHighlightRenderer: OverlayRenderer {
    let config: CursorHighlightConfig
    var position: CGPoint
    var clickProgress: CGFloat

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let color = NSColor(hex: config.colorHex)?.cgColor else { return }

        context.saveGState()

        // Outer glow
        context.setFillColor(color.copy(alpha: 0.2)!)
        context.fillEllipse(in: CGRect(x: position.x - config.radius, y: position.y - config.radius, width: config.radius * 2, height: config.radius * 2))

        // Inner dot
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(x: position.x - config.radius * 0.3, y: position.y - config.radius * 0.3, width: config.radius * 0.6, height: config.radius * 0.6))

        // Click ripple
        if config.showClicks && clickProgress > 0 {
            let rippleRadius = config.radius * (1 + clickProgress * 2)
            context.setStrokeColor(color)
            context.setLineWidth(2 * (1 - clickProgress))
            context.strokeEllipse(in: CGRect(x: position.x - rippleRadius, y: position.y - rippleRadius, width: rippleRadius * 2, height: rippleRadius * 2))
        }

        context.restoreGState()
    }
}
