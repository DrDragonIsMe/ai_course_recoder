import AppKit
import Combine

/// Tracks global key presses for on-screen keystroke display.
final class KeyPressMonitor {
    @Published var recentKeys: [String] = []

    private var monitor: Any?

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(event: NSEvent) {
        var parts: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { parts.append("Cmd") }
        if flags.contains(.option) { parts.append("Opt") }
        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.shift) { parts.append("Shift") }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            parts.append(chars.uppercased())
        }

        let combo = parts.joined(separator: "+")
        guard !combo.isEmpty else { return }

        recentKeys.append(combo)
        if recentKeys.count > 5 {
            recentKeys.removeFirst()
        }
    }
}
