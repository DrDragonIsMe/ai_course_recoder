import AppKit
import Combine

/// Tracks global cursor position and click events for overlay rendering.
final class CursorTracker {
    @Published var position: CGPoint = .zero
    @Published var clickProgress: CGFloat = 0

    private var monitors: [Any?] = []
    private var animationTimer: Timer?

    func start() {
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: moveMask) { [weak self] event in
            self?.position = event.locationInWindow
        })

        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] _ in
            self?.triggerClick()
        })
    }

    func stop() {
        monitors.forEach { monitor in
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        monitors.removeAll()
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func triggerClick() {
        clickProgress = 1.0
        animationTimer?.invalidate()
        let startTime = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let duration = self.configDuration
            self.clickProgress = max(0, 1.0 - CGFloat(elapsed / duration))
            if self.clickProgress <= 0 {
                timer.invalidate()
                self.animationTimer = nil
            }
        }
    }

    private var configDuration: TimeInterval {
        0.4
    }
}
