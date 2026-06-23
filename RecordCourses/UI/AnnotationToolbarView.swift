import SwiftUI

/// Toolbar for selecting annotation tool, color, and line width.
struct AnnotationToolbarView: View {
    @ObservedObject var annotationSession: AnnotationSession

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .black]
    private let lineWidths: [CGFloat] = [2, 4, 6, 10]

    var body: some View {
        VStack(spacing: 16) {
            toolSection
            Divider()
            colorSection
            Divider()
            widthSection
            Divider()
            actionSection
        }
        .padding(12)
        .frame(width: 72)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }

    // MARK: - Sections

    private var toolSection: some View {
        VStack(spacing: 8) {
            ForEach([AnnotationTool.pen, .arrow, .rectangle, .circle, .eraser], id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: annotationSession.currentTool == tool,
                    action: { annotationSession.currentTool = tool }
                )
            }
        }
    }

    private var colorSection: some View {
        VStack(spacing: 8) {
            ForEach(colors, id: \.self) { color in
                ColorButton(
                    color: color,
                    isSelected: color.nsColor == annotationSession.currentColor,
                    action: { annotationSession.currentColor = color.nsColor }
                )
            }
        }
    }

    private var widthSection: some View {
        VStack(spacing: 8) {
            ForEach(lineWidths, id: \.self) { width in
                WidthButton(
                    width: width,
                    isSelected: annotationSession.currentLineWidth == width,
                    action: { annotationSession.currentLineWidth = width }
                )
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 8) {
            Button(action: { annotationSession.undoLastStroke() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.plain)
            .disabled(!annotationSession.canUndo)
            .help("Undo")

            Button(action: { annotationSession.redoLastStroke() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.plain)
            .disabled(!annotationSession.canRedo)
            .help("Redo")

            Button(action: { annotationSession.clearAll() }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(annotationSession.strokes.isEmpty)
            .help("Clear all")
        }
    }
}

// MARK: - Buttons

private struct ToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }
}

private struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct WidthButton: View {
    let width: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 24, height: width)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Helpers

private extension Color {
    var nsColor: NSColor {
        NSColor(self)
    }
}

// MARK: - Preview

#Preview {
    AnnotationToolbarView(annotationSession: AnnotationSession())
}
