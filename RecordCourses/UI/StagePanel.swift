import SwiftUI
import AVFoundation

/// Center stage preview of the recording composition.
struct StagePanel: View {
    @EnvironmentObject var viewModel: RecordingViewModel

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                stageToolbar

                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )

                        VStack(spacing: 8) {
                            if viewModel.config.enableCamera, let session = viewModel.cameraSession {
                                PreviewView(captureSession: session)
                                    .frame(
                                        width: cameraSize(in: geometry.size),
                                        height: cameraSize(in: geometry.size) * 0.75
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 8)
                            }

                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary.opacity(0.4))

                            Text("Recording Stage")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text(viewModel.config.layout.name)
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                    .padding(12)
                }
            }
            .padding(12)
        }
    }

    private var stageToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedSlideTitle)
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.config.layout.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Display", selection: $viewModel.selectedDisplayID) {
                ForEach(displayOptions(), id: \.id) { option in
                    Text(option.name)
                        .tag(option.id as CGDirectDisplayID?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            HStack(spacing: 8) {
                Toggle("Camera", isOn: $viewModel.config.enableCamera)
                Toggle("Mic", isOn: $viewModel.config.enableMicrophone)
            }
            .controlSize(.small)
        }
    }

    private var selectedSlideTitle: String {
        guard let id = viewModel.selectedSlideID,
              let slide = viewModel.slides.first(where: { $0.id == id }) else {
            return "No Slide Selected"
        }
        return "\(slide.pageNumber). \(slide.title)"
    }

    private func cameraSize(in stageSize: CGSize) -> CGFloat {
        min(stageSize.width, stageSize.height) * 0.35
    }

    private struct DisplayOption: Identifiable {
        let id: CGDirectDisplayID
        let name: String
    }

    private func displayOptions() -> [DisplayOption] {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        return viewModel.displays.enumerated().map { index, display in
            let matchScreen = NSScreen.screens.first {
                ($0.deviceDescription[screenNumberKey] as? CGDirectDisplayID) == display.displayID
            }
            let name = matchScreen?.localizedName ?? "Display \(index + 1)"
            return DisplayOption(id: display.displayID, name: name)
        }
    }
}

// MARK: - Preview

#Preview {
    StagePanel()
        .environmentObject(RecordingViewModel())
}
