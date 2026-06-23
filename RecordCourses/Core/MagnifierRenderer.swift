import Foundation
import CoreGraphics
import AppKit

struct MagnifierRenderer: OverlayRenderer {
    let config: MagnifierConfig
    let sourceImage: CGImage?

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled, let sourceImage = sourceImage else { return }
        guard let borderColor = NSColor(hex: config.borderColorHex)?.cgColor else { return }

        let lensRect = CGRect(
            x: config.targetPoint.x - config.radius,
            y: config.targetPoint.y - config.radius,
            width: config.radius * 2,
            height: config.radius * 2
        )

        context.saveGState()
        let path = NSBezierPath(ovalIn: lensRect)
        path.addClip()

        let cropRect = CGRect(
            x: config.targetPoint.x - config.radius / config.scale,
            y: config.targetPoint.y - config.radius / config.scale,
            width: config.radius * 2 / config.scale,
            height: config.radius * 2 / config.scale
        )

        if let cropped = sourceImage.cropping(to: cropRect) {
            context.draw(cropped, in: lensRect)
        }

        context.restoreGState()

        context.setStrokeColor(borderColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: lensRect)
    }
}
