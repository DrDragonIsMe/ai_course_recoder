import Foundation
import CoreGraphics
import AppKit

struct KeyPressRenderer: OverlayRenderer {
    let config: KeyPressOverlayConfig
    let recentKeys: [String]

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled, !recentKeys.isEmpty else { return }
        guard let bg = NSColor(hex: config.backgroundColorHex),
              let fg = NSColor(hex: config.textColorHex) else { return }

        let badgeHeight: CGFloat = 28
        let spacing: CGFloat = 8
        let padding: CGFloat = 20
        var x = config.position == .bottomLeft ? padding : rect.width - padding
        let y = padding

        for key in recentKeys.suffix(config.maxKeys).reversed() {
            let text = key as NSString
            let font = NSFont.systemFont(ofSize: 14, weight: .medium)
            let size = text.size(withAttributes: [.font: font])
            let badgeWidth = size.width + 16
            let badgeRect = CGRect(
                x: config.position == .bottomLeft ? x : x - badgeWidth,
                y: y,
                width: badgeWidth,
                height: badgeHeight
            )

            context.saveGState()
            context.setFillColor(bg.cgColor)
            context.fillRoundedRect(badgeRect, cornerRadius: 6)

            context.setFillColor(fg.cgColor)
            text.draw(at: CGPoint(x: badgeRect.minX + 8, y: badgeRect.minY + 5), withAttributes: [
                .font: font,
                .foregroundColor: fg
            ])
            context.restoreGState()

            x += config.position == .bottomLeft ? badgeWidth + spacing : -(badgeWidth + spacing)
        }
    }
}
