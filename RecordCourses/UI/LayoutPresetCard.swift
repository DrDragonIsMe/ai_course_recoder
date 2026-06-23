import SwiftUI

/// Visual card representing a recording layout preset.
struct LayoutPresetCard: View {
    let layout: RecordingLayout
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                layoutPreview
                Text(layout.name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var layoutPreview: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))

                if layout.cameraLayout.isVisible {
                    let cameraRect = previewRect(for: layout.cameraLayout.region, in: geometry.size)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: cameraRect.width, height: cameraRect.height)
                        .position(x: cameraRect.midX, y: cameraRect.midY)
                }

                let screenRect = previewRect(for: layout.screenRegion, in: geometry.size)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.4))
                    .frame(width: screenRect.width, height: screenRect.height)
                    .position(x: screenRect.midX, y: screenRect.midY)
            }
            .padding(8)
        }
    }

    private func previewRect(for region: LayoutRegion, in containerSize: CGSize) -> CGRect {
        let rect = region.rect(for: containerSize)
        let padded = CGRect(x: 8, y: 8, width: containerSize.width - 16, height: containerSize.height - 16)
        return CGRect(
            x: padded.minX + rect.minX / containerSize.width * padded.width,
            y: padded.minY + rect.minY / containerSize.height * padded.height,
            width: rect.width / containerSize.width * padded.width,
            height: rect.height / containerSize.height * padded.height
        )
    }
}

// MARK: - Preview

#Preview {
    LayoutPresetCard(layout: .cornerPIP(), isSelected: false) {}
        .frame(width: 120)
}
