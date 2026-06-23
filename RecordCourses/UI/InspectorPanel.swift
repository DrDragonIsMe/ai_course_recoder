import SwiftUI

/// Right-side inspector panel for layout, overlays, audio/video, and output settings.
struct InspectorPanel: View {
    @EnvironmentObject var viewModel: RecordingViewModel
    @State private var selectedTab: InspectorTab = .layout

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .layout:
                        layoutSection
                    case .overlays:
                        OverlaySettingsPanel(layout: $viewModel.config.layout)
                    case .video:
                        videoSection
                    case .audio:
                        audioSection
                    case .output:
                        outputSection
                    }
                }
                .padding(12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Sections

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Layout Presets", systemImage: "rectangle.split.2x1")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RecordingLayout.allPresets, id: \.name) { layout in
                    LayoutPresetCard(layout: layout, isSelected: viewModel.config.layout.name == layout.name) {
                        viewModel.config.layout = layout
                        viewModel.config.enableCamera = layout.cameraLayout.isVisible
                    }
                }
            }
        }
    }

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Quality") {
                Picker("Quality", selection: $viewModel.config.quality) {
                    ForEach(RecordingConfig.Quality.allCases, id: \.self) { quality in
                        Text(quality.rawValue.capitalized).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            LabeledContent("Codec") {
                Picker("Codec", selection: $viewModel.config.videoCodec) {
                    ForEach(RecordingConfig.VideoCodec.allCases, id: \.self) { codec in
                        Text(codec.rawValue.uppercased()).tag(codec)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            LabeledContent("Frame Rate") {
                Stepper("\(viewModel.config.fps) fps", value: $viewModel.config.fps, in: 15...60, step: 5)
            }

            LabeledContent("Camera") {
                Picker("Position", selection: $viewModel.config.cameraPosition) {
                    ForEach(RecordingConfig.CameraPosition.allCases, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            LabeledContent("Size") {
                Picker("Size", selection: $viewModel.config.cameraSize) {
                    ForEach(RecordingConfig.CameraSize.allCases, id: \.self) { size in
                        Text(size.rawValue.capitalized).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            Toggle("Show Cursor", isOn: $viewModel.config.showCursor)
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Microphone", isOn: $viewModel.config.enableMicrophone)
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Format") {
                Picker("Format", selection: $viewModel.config.outputFormat) {
                    ForEach(RecordingConfig.OutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            Button("Open Output Folder") {
                viewModel.openOutputFolder()
            }
        }
    }
}

// MARK: - Inspector Tab

private enum InspectorTab: String, CaseIterable {
    case layout
    case overlays
    case video
    case audio
    case output

    var title: String {
        switch self {
        case .layout: return "Layout"
        case .overlays: return "Overlays"
        case .video: return "Video"
        case .audio: return "Audio"
        case .output: return "Output"
        }
    }
}

// MARK: - Preview

#Preview {
    InspectorPanel()
        .environmentObject(RecordingViewModel())
        .frame(width: 300)
}
