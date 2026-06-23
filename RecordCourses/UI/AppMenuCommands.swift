import SwiftUI

/// Menu bar commands for the studio window.
struct AppMenuCommands: Commands {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Recording") {
                Task {
                    await viewModel.startRecording()
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(viewModel.isRecording || viewModel.state == .configuring)

            Divider()

            Button("Open Output Folder") {
                viewModel.openOutputFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandMenu("Record") {
            Button(viewModel.isRecording ? "Stop Recording" : "Start Recording") {
                Task {
                    if viewModel.isRecording {
                        await viewModel.stopRecording()
                    } else {
                        await viewModel.startRecording()
                    }
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Toggle Annotation") {
                viewModel.toggleAnnotationDrawingMode()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(!viewModel.isRecording)
        }

        CommandMenu("View") {
            Toggle("Show Slides Panel", isOn: $viewModel.showSlidesPanel)
                .keyboardShortcut("1", modifiers: [.command, .option])

            Toggle("Show Inspector", isOn: $viewModel.showInspectorPanel)
                .keyboardShortcut("2", modifiers: [.command, .option])

            Toggle("Show Clip Timeline", isOn: $viewModel.showTimelinePanel)
                .keyboardShortcut("3", modifiers: [.command, .option])
        }

        CommandMenu("Edit") {
            Button("Clear Annotations") {
                viewModel.annotationSession?.clearAll()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(viewModel.annotationSession?.strokes.isEmpty ?? true)
        }
    }
}
