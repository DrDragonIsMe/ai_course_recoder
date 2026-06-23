import Foundation
import CoreGraphics
import AppKit

struct ChapterProgressRenderer: OverlayRenderer {
    let config: ChapterProgressConfig
    let progress: CGFloat

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let activeColor = NSColor(hex: config.activeColorHex)?.cgColor,
              let inactiveColor = NSColor(hex: config.inactiveColorHex)?.cgColor else { return }

        let barY = rect.height - config.barHeight - 8
        let barRect = CGRect(x: 0, y: barY, width: rect.width, height: config.barHeight)

        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(inactiveColor)
        context.fill(barRect)

        context.setFillColor(activeColor)
        let progressWidth = rect.width * max(0, min(1, progress))
        context.fill(CGRect(x: 0, y: barY, width: progressWidth, height: config.barHeight))

        let count = config.chapters.count
        guard count > 1 else { return }

        let markerSize: CGFloat = 8
        for (index, _) in config.chapters.enumerated() {
            let x = rect.width * CGFloat(index) / CGFloat(count - 1)
            let markerRect = CGRect(
                x: x - markerSize / 2,
                y: barY - (markerSize - config.barHeight) / 2,
                width: markerSize,
                height: markerSize
            )
            context.setFillColor(index <= config.currentChapter ? activeColor : inactiveColor)
            context.fillEllipse(in: markerRect)
        }
    }
}
