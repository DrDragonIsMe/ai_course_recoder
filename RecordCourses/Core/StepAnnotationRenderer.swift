import Foundation
import CoreGraphics
import AppKit

struct StepAnnotationRenderer: OverlayRenderer {
    let config: StepAnnotationConfig

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let color = NSColor(hex: config.colorHex)?.cgColor else { return }

        for step in config.steps {
            context.saveGState()
            context.setStrokeColor(color)
            context.setFillColor(color)
            context.setLineWidth(2)
            context.setLineCap(.round)

            // Target circle
            let target = CGRect(
                x: step.targetPoint.x - 8,
                y: step.targetPoint.y - 8,
                width: 16,
                height: 16
            )
            context.strokeEllipse(in: target)

            // Number badge
            let badgeRect = CGRect(
                x: step.targetPoint.x + 12,
                y: step.targetPoint.y - 12,
                width: 24,
                height: 24
            )
            context.fillEllipse(in: badgeRect)
            context.setFillColor(NSColor.white.cgColor)
            let text = "\(step.number)" as NSString
            text.draw(at: CGPoint(x: badgeRect.minX + 7, y: badgeRect.minY + 4), withAttributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)
            ])

            // Text label
            context.setFillColor(color)
            let label = step.text as NSString
            label.draw(at: CGPoint(x: step.targetPoint.x + 40, y: step.targetPoint.y - 8), withAttributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor(cgColor: color) ?? .orange
            ])

            context.restoreGState()
        }
    }
}
