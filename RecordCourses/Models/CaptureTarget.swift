import Foundation

/// How the user wants to capture content.
enum CaptureMode: String, Codable, CaseIterable, Identifiable {
    case fullScreen
    case window
    case application

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullScreen: "Entire Screen"
        case .window: "Specific Window"
        case .application: "Specific App"
        }
    }

    var systemImage: String {
        switch self {
        case .fullScreen: "display"
        case .window: "macwindow"
        case .application: "app"
        }
    }
}
