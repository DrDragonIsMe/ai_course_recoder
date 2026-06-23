import SwiftUI

/// Main recording studio window: slide deck, stage preview, inspector, and timeline.
struct RecordingWindow: View {
    @EnvironmentObject var viewModel: RecordingViewModel
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            if !viewModel.hasRequiredPermissions {
                permissionBanner
            }

            studioBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            recordBar
        }
        .task {
            await viewModel.loadDisplays()
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
                return event
            }
        }
        .onDisappear {
            if let keyMonitor = keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }
        .alert("Recording Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .alert("Recording Saved", isPresented: .constant(viewModel.outputReadyMessage != nil)) {
            Button("OK", role: .cancel) {
                viewModel.outputReadyMessage = nil
            }
        } message: {
            if let message = viewModel.outputReadyMessage {
                Text(message)
            }
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "record.circle")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("Record Courses")
                    .font(.headline)
            }

            Spacer()

            HStack(spacing: 8) {
                Toggle("Slides", isOn: $viewModel.showSlidesPanel)
                    .toggleStyle(.button)
                    .help("Toggle slide deck")

                Toggle("Inspector", isOn: $viewModel.showInspectorPanel)
                    .toggleStyle(.button)
                    .help("Toggle inspector")

                Toggle("Clips", isOn: $viewModel.showTimelinePanel)
                    .toggleStyle(.button)
                    .help("Toggle clip timeline")
            }
            .controlSize(.small)

            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
            Text(viewModel.isRecording ? "Recording" : "Ready")
                .font(.caption)
                .foregroundStyle(viewModel.isRecording ? Color.red : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(Capsule())
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Screen recording, camera, or microphone permission is missing. Open System Settings to grant access.")
                .font(.caption)
            Spacer()
            Button("Open Settings") {
                viewModel.openPrivacySettings()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Studio Body

    @ViewBuilder
    private var studioBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if viewModel.showSlidesPanel {
                    SlideDeckPanel()
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
                    Divider()
                }

                StagePanel()
                    .frame(minWidth: 360)

                if viewModel.showInspectorPanel {
                    Divider()
                    InspectorPanel()
                        .frame(minWidth: 240, idealWidth: 280, maxWidth: 380)
                }
            }

            if viewModel.showTimelinePanel {
                TimelineStrip()
            }
        }
    }

    // MARK: - Record Bar

    private var recordBar: some View {
        HStack(spacing: 16) {
            Text(viewModel.durationString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 72)

            Spacer()

            if viewModel.isRecording, let annotationSession = viewModel.annotationSession {
                AnnotationToolbarView(annotationSession: annotationSession)
                    .frame(height: 64)
            }

            Spacer()

            if viewModel.isRecording {
                Button(action: {
                    Task {
                        await viewModel.stopRecording()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            } else {
                Button(action: {
                    Task {
                        await viewModel.startRecording()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle")
                        Text("Record")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.state == .configuring)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Keyboard Shortcuts

    private func handleKeyEvent(_ event: NSEvent) {
        guard viewModel.isRecording else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommand = modifiers.contains(.command)
        let isShift = modifiers.contains(.shift)
        let character = event.charactersIgnoringModifiers?.lowercased()

        if isCommand && isShift && character == "a" {
            viewModel.toggleAnnotationDrawingMode()
            return
        }

        if !isCommand && !isShift && character == "d" {
            viewModel.toggleAnnotationDrawingMode()
            return
        }

        if isCommand && isShift && character == "s" {
            Task {
                await viewModel.stopRecording()
            }
            return
        }

        guard viewModel.isAnnotationDrawingModeEnabled else { return }

        if event.keyCode == 53 {
            viewModel.toggleAnnotationDrawingMode()
            return
        }

        if !isCommand && character == "c" {
            viewModel.annotationSession?.clearAll()
            return
        }

        guard let annotationSession = viewModel.annotationSession else { return }

        if !isCommand && !isShift {
            switch character {
            case "1": annotationSession.currentTool = .pen
            case "2": annotationSession.currentTool = .arrow
            case "3": annotationSession.currentTool = .rectangle
            case "4": annotationSession.currentTool = .circle
            case "5": annotationSession.currentTool = .eraser
            case "r": annotationSession.currentColor = .red
            case "o": annotationSession.currentColor = .orange
            case "y": annotationSession.currentColor = .yellow
            case "g": annotationSession.currentColor = .green
            case "b": annotationSession.currentColor = .blue
            case "p": annotationSession.currentColor = .purple
            case "w": annotationSession.currentColor = .white
            case "k": annotationSession.currentColor = .black
            default:
                break
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecordingWindow()
        .environmentObject(RecordingViewModel())
        .frame(width: 1200, height: 800)
}
