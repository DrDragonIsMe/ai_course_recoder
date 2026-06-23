import Foundation
import CoreGraphics
import AppKit

struct WatermarkRenderer: OverlayRenderer {
    let config: WatermarkConfig

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let textColor = NSColor(hex: config.textColorHex)?.cgColor else { return }

        let logo = config.logoText as NSString
        let name = config.instructorName as NSString
        let logoFont = NSFont.systemFont(ofSize: 18, weight: .bold)
        let nameFont = NSFont.systemFont(ofSize: 14)
        let logoSize = logo.size(withAttributes: [.font: logoFont])
        let nameSize = name.size(withAttributes: [.font: nameFont])

        let padding: CGFloat = 20
        let x = config.position == .bottomLeft ? padding : rect.width - max(logoSize.width, nameSize.width) - padding
        let y = padding

        context.saveGState()
        context.setFillColor(textColor)
        logo.draw(at: CGPoint(x: x, y: y + nameSize.height + 4), withAttributes: [
            .font: logoFont,
            .foregroundColor: NSColor(cgColor: textColor) ?? .black
        ])
        name.draw(at: CGPoint(x: x, y: y), withAttributes: [
            .font: nameFont,
            .foregroundColor: NSColor(cgColor: textColor) ?? .black
        ])
        context.restoreGState()
    }
}
