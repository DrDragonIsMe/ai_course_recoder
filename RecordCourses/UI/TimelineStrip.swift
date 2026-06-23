import SwiftUI

/// Bottom timeline / lightweight clip strip for recent recordings.
struct TimelineStrip: View {
    @EnvironmentObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Label("Clips", systemImage: "film")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(viewModel.recentRecordings.count) recordings")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: { viewModel.refreshRecentRecordings() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recentRecordings, id: \.self) { url in
                        ClipCard(url: url)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(minHeight: 140, idealHeight: 160, maxHeight: 200)
    }
}

// MARK: - Clip Card

private struct ClipCard: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.windowBackgroundColor))

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            HStack(spacing: 8) {
                Button("Play") {
                    NSWorkspace.shared.open(url)
                }
                .font(.caption2)
                .buttonStyle(.borderless)

                Button("Trim") {
                    // Lightweight trim placeholder: future feature.
                }
                .font(.caption2)
                .buttonStyle(.borderless)
                .disabled(true)
            }
        }
        .frame(width: 146)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = RecordingViewModel()
    TimelineStrip()
        .environmentObject(viewModel)
}
