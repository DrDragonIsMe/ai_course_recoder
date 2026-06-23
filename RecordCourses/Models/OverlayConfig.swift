import Foundation

/// Base protocol for all overlay configurations.
protocol OverlayConfig: Equatable, Codable {
    var isEnabled: Bool { get set }
}
