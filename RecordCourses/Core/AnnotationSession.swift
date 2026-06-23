import Foundation
import AppKit
import CoreGraphics

/// Manages annotation strokes during a recording session.
@MainActor
final class AnnotationSession: ObservableObject {
    @Published var strokes: [Stroke] = []
    @Published var currentTool: AnnotationTool = .pen
    @Published var currentColor: NSColor = .red
    @Published var currentLineWidth: CGFloat = 3.0

    private var currentStroke: Stroke?
    private var undoStack: [Stroke] = []

    // MARK: - Stroke Building

    /// Begin a new stroke at the given point.
    func beginStroke(at point: NSPoint) {
        currentStroke = Stroke(
            tool: currentTool,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [point]
        )
    }

    /// Add a point to the current stroke.
    func addPoint(_ point: NSPoint) {
        guard var stroke = currentStroke else { return }
        stroke.points.append(point)
        currentStroke = stroke
    }

    /// Finish the current stroke and commit it.
    func finishStroke() {
        guard let stroke = currentStroke, !stroke.points.isEmpty else { return }
        strokes.append(stroke)
        currentStroke = nil
        undoStack.removeAll()
    }

    // MARK: - Undo / Redo

    /// Undo the last committed stroke.
    func undoLastStroke() {
        guard let last = strokes.popLast() else { return }
        undoStack.append(last)
    }

    /// Redo the last undone stroke.
    func redoLastStroke() {
        guard let last = undoStack.popLast() else { return }
        strokes.append(last)
    }

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !undoStack.isEmpty }

    /// Clear all strokes.
    func clearAll() {
        strokes.removeAll()
        undoStack.removeAll()
        currentStroke = nil
    }

    // MARK: - Drawing

    /// Draw all committed and current strokes on the given graphics context.
    func draw(on context: CGContext) {
        for stroke in strokes {
            drawStroke(stroke, in: context)
        }
        if let currentStroke = currentStroke {
            drawStroke(currentStroke, in: context)
        }
    }

    private func drawStroke(_ stroke: Stroke, in context: CGContext) {
        let points = stroke.points
        guard points.count > 1 else { return }

        context.saveGState()
        context.setStrokeColor(stroke.color.cgColor)
        context.setLineWidth(stroke.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch stroke.tool {
        case .pen:
            context.beginPath()
            context.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                context.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.strokePath()

        case .arrow:
            drawArrow(points: points, in: context)

        case .rectangle:
            guard let first = points.first, let last = points.last else { break }
            let rect = CGRect(origin: first, size: CGSize(width: last.x - first.x, height: last.y - first.y))
            context.stroke(rect)

        case .circle:
            guard let first = points.first, let last = points.last else { break }
            let rect = CGRect(origin: first, size: CGSize(width: last.x - first.x, height: last.y - first.y))
            context.strokeEllipse(in: rect)

        case .eraser:
            context.setBlendMode(.clear)
            context.beginPath()
            context.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for point in points.dropFirst() {
                context.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.strokePath()

        case .text, .cursorHighlight:
            // Phase 3.5: text and cursor highlight are placeholders for now.
            break
        }

        context.restoreGState()
    }

    private func drawArrow(points: [NSPoint], in context: CGContext) {
        guard let start = points.first, let end = points.last, start != end else { return }

        context.beginPath()
        context.move(to: CGPoint(x: start.x, y: start.y))
        context.addLine(to: CGPoint(x: end.x, y: end.y))
        context.strokePath()

        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        let angle = atan2(end.y - start.y, end.x - start.x)

        context.beginPath()
        context.move(to: CGPoint(x: end.x, y: end.y))
        context.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        ))
        context.move(to: CGPoint(x: end.x, y: end.y))
        context.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        ))
        context.strokePath()
    }
}
