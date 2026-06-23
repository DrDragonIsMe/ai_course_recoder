import Foundation
import CoreGraphics
import AppKit

struct SubtitleRenderer: OverlayRenderer {
    let config: SubtitleConfig
    let primary: String
    let secondary: String?

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled, !primary.isEmpty else { return }
        guard let textColor = NSColor(hex: config.textColorHex),
              let outlineColor = NSColor(hex: config.outlineColorHex) else { return }

        let text = config.bilingual && secondary != nil ? "\(primary)\n\(secondary!)" : primary
        let font = NSFont.systemFont(ofSize: config.fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .strokeColor: outlineColor,
            .strokeWidth: -3.0
        ]
        let size = text.size(withAttributes: attributes)
        let point = CGPoint(x: (rect.width - size.width) / 2, y: 40)
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
}
