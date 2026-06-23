import SwiftUI
import PDFKit

/// Left-side slide / PPT deck panel in the studio layout.
struct SlideDeckPanel: View {
    @EnvironmentObject var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.slides) { slide in
                        SlideThumbnail(slide: slide, isSelected: viewModel.selectedSlideID == slide.id) {
                            viewModel.selectSlide(id: slide.id)
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var panelHeader: some View {
        HStack {
            Label("Slides", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(action: { importSlides() }) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.borderless)
            .help("Import PDF slides")

            Button(action: { viewModel.addSlide() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.borderless)
            .help("Add slide")
        }
    }

    private func importSlides() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a PDF to import as slides"

        if panel.runModal() == .OK, let url = panel.url {
            importPDF(url: url)
        }
    }

    private func importPDF(url: URL) {
        guard let pdf = PDFDocument(url: url) else { return }
        let startIndex = viewModel.slides.count
        for pageIndex in 0..<pdf.pageCount {
            let number = startIndex + pageIndex + 1
            viewModel.slides.append(
                SlideItem(title: "Slide \(number)", pageNumber: number)
            )
        }
        viewModel.selectedSlideID = viewModel.slides.last?.id
    }
}

// MARK: - Slide Thumbnail

private struct SlideThumbnail: View {
    @EnvironmentObject var viewModel: RecordingViewModel
    let slide: SlideItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.windowBackgroundColor))

                    Text("\(slide.pageNumber)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))

                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)

                Text(slide.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeSlide(id: slide.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = RecordingViewModel()
    SlideDeckPanel()
        .environmentObject(viewModel)
        .frame(width: 220)
}
