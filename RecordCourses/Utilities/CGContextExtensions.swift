import Foundation
import CoreGraphics
import AppKit

extension CGContext {
    /// Fill a rounded rectangle.
    func fillRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.fill()
    }

    /// Stroke a rounded rectangle.
    func strokeRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.stroke()
    }
}
