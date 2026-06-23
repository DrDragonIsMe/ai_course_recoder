import Foundation
import AppKit

/// Represents a single annotation stroke drawn during recording.
struct Stroke: Identifiable {
    let id: UUID
    let tool: AnnotationTool
    let color: NSColor
    let lineWidth: CGFloat
    var points: [NSPoint]
    let timestamp: Date

    init(tool: AnnotationTool, color: NSColor, lineWidth: CGFloat, points: [NSPoint]) {
        self.id = UUID()
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.timestamp = Date()
    }
}
