import Foundation

/// Annotation tools available during recording.
enum AnnotationTool: String, Codable, CaseIterable, Identifiable {
    case pen
    case arrow
    case rectangle
    case circle
    case eraser
    case text
    case cursorHighlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: "Pen"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .circle: "Circle"
        case .eraser: "Eraser"
        case .text: "Text"
        case .cursorHighlight: "Cursor Highlight"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil"
        case .arrow: "arrowshape.turn.up.left"
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .eraser: "eraser"
        case .text: "textformat"
        case .cursorHighlight: "cursorarrow"
        }
    }
}
