import SwiftUI
import UniformTypeIdentifiers

struct OverlaySettingsPanel: View {
    @Binding var layout: RecordingLayout

    @State private var showSRTImporter = false
    @State private var importedSubtitleCount = 0
    @State private var showImportConfirmation = false

    var body: some View {
        Form {
            Section("Watermark") {
                Toggle("Enabled", isOn: $layout.watermark.isEnabled)
                TextField("Logo", text: $layout.watermark.logoText)
                TextField("Instructor", text: $layout.watermark.instructorName)
                Picker("Position", selection: $layout.watermark.position) {
                    Text("Bottom Left").tag(WatermarkConfig.Position.bottomLeft)
                    Text("Bottom Right").tag(WatermarkConfig.Position.bottomRight)
                }
            }

            Section("Cursor") {
                Toggle("Highlight", isOn: $layout.cursorHighlight.isEnabled)
                Toggle("Click Ripple", isOn: $layout.cursorHighlight.showClicks)
            }

            Section("Keystrokes") {
                Toggle("Enabled", isOn: $layout.keyPressOverlay.isEnabled)
                Picker("Position", selection: $layout.keyPressOverlay.position) {
                    Text("Bottom Left").tag(KeyPressOverlayConfig.Position.bottomLeft)
                    Text("Bottom Right").tag(KeyPressOverlayConfig.Position.bottomRight)
                }
            }

            Section("Magnifier") {
                Toggle("Enabled", isOn: $layout.magnifier.isEnabled)
            }

            Section("Steps") {
                Toggle("Enabled", isOn: $layout.stepAnnotation.isEnabled)
            }

            Section("Subtitles") {
                Toggle("Enabled", isOn: $layout.subtitle.isEnabled)
                Toggle("Bilingual", isOn: $layout.subtitle.bilingual)
                Button("Import SRT…") {
                    showSRTImporter = true
                }
                if importedSubtitleCount > 0 {
                    Text("\(importedSubtitleCount) subtitle entries imported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Progress") {
                Toggle("Enabled", isOn: $layout.chapterProgress.isEnabled)
                chapterEditor
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 300)
        .fileImporter(isPresented: $showSRTImporter, allowedContentTypes: [.plainText]) { result in
            handleSRTImport(result: result)
        }
        .alert("Subtitles Imported", isPresented: $showImportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(importedSubtitleCount) subtitle entries were loaded from the SRT file.")
        }
    }

    private var chapterEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($layout.chapterProgress.chapters) { $marker in
                HStack {
                    TextField("Title", text: $marker.title)
                    TextField("Time (s)", value: $marker.timestamp, format: .number)
                        .frame(width: 80)
                    Button {
                        removeChapter(marker)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                layout.chapterProgress.chapters.append(
                    ChapterMarker(title: "Chapter \(layout.chapterProgress.chapters.count + 1)", timestamp: 0)
                )
            } label: {
                Label("Add Chapter", systemImage: "plus")
            }
        }
    }

    private func removeChapter(_ marker: ChapterMarker) {
        layout.chapterProgress.chapters.removeAll { $0.id == marker.id }
    }

    private func handleSRTImport(result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let content = try String(contentsOf: url, encoding: .utf8)
            let entries = SubtitleLoader.parse(srt: content)
            layout.subtitle.entries = entries
            importedSubtitleCount = entries.count
            showImportConfirmation = entries.count > 0
        } catch {
            importedSubtitleCount = 0
        }
    }
}
