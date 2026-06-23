import SwiftUI

/// Settings panel accessible via Cmd+,
struct SettingsPanel: View {
    @AppStorage("outputDirectory") private var outputDirectoryPath: String = ""

    var body: some View {
        Form {
            Section("General") {
                Text("Record Courses")
                    .font(.headline)
                Text("A course recording app for macOS.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Output") {
                TextField("Output Directory", text: $outputDirectoryPath)
                    .disabled(true)
                Button("Choose...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = []
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.canChooseFiles = false
                    panel.message = "Select output directory"

                    if panel.runModal() == .OK, let url = panel.url {
                        outputDirectoryPath = url.path()
                    }
                }
            }

            Section("About") {
                Text("Version 1.0")
                Text("Built with ScreenCaptureKit + AVFoundation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview {
    SettingsPanel()
}
