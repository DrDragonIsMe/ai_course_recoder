import Foundation
import ScreenCaptureKit
import AppKit

/// Helpers for screen and display discovery.
enum ScreenHelper {
    /// Find an SCDisplay by display ID.
    static func findDisplay(by id: CGDirectDisplayID) async -> SCDisplay? {
        let displays = await ScreenCaptureService.availableDisplays()
        return displays.first { $0.displayID == id }
    }

    /// Get the primary display.
    static func primaryDisplay() async -> SCDisplay? {
        let displays = await ScreenCaptureService.availableDisplays()
        return displays.first { $0.displayID == CGMainDisplayID() }
    }

    /// Get display dimensions.
    static func displayDimensions(_ display: SCDisplay) -> (width: Int, height: Int) {
        (display.width, display.height)
    }
}
