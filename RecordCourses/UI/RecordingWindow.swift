import SwiftUI

/// Main recording window — configuration, preview, and controls.
struct RecordingWindow: View {
    @EnvironmentObject var viewModel: RecordingViewModel
    @State private var showPermissionAlert = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Permission warning
            if !viewModel.hasRequiredPermissions {
                permissionBanner
            }

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    captureModeSection
                    layoutSection
                    displaySection
                    videoSettingsSection
                    audioSettingsSection
                    outputSettingsSection
                }
                .padding(20)
            }

            // Annotation toolbar visible while recording
            if viewModel.isRecording, let annotationSession = viewModel.annotationSession {
                HStack {
                    Spacer()
                    AnnotationToolbarView(annotationSession: annotationSession)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }

            // Bottom bar
            bottomBar
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

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "record.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Record Courses")
                .font(.headline)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Screen recording, camera, or microphone permission is missing. Open System Settings to grant access.")
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
            Button("Open Settings") {
                viewModel.openPrivacySettings()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            if viewModel.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("Recording")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(Capsule())
    }

    // MARK: - Capture Mode

    private var captureModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Capture Mode", systemImage: "video")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CaptureMode.allCases) { mode in
                    CaptureModeCard(mode: mode, isSelected: viewModel.config.captureMode == mode) {
                        viewModel.config.captureMode = mode
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Display Selection

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Display", systemImage: "display")
                .font(.headline)

            Picker("Display", selection: $viewModel.selectedDisplayID) {
                ForEach(displayOptions(), id: \.id) { option in
                    Text(option.name)
                        .tag(option.id as CGDirectDisplayID?)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Video Settings

    private var videoSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Video", systemImage: "camera.video")
                .font(.headline)

            HStack(spacing: 20) {
                Toggle("Camera", isOn: $viewModel.config.enableCamera)
                Toggle("Show Cursor", isOn: $viewModel.config.showCursor)
            }

            if viewModel.config.enableCamera {
                VStack(alignment: .leading, spacing: 8) {
                    PreviewView(captureSession: viewModel.cameraSession)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        Text("Position")
                        Spacer()
                        Picker("Position", selection: $viewModel.config.cameraPosition) {
                            ForEach(RecordingConfig.CameraPosition.allCases, id: \.self) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }

                    HStack {
                        Text("Size")
                        Spacer()
                        Picker("Size", selection: $viewModel.config.cameraSize) {
                            ForEach(RecordingConfig.CameraSize.allCases, id: \.self) { size in
                                Text(size.rawValue.capitalized).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality")
                    Spacer()
                    Picker("Quality", selection: $viewModel.config.quality) {
                        ForEach(RecordingConfig.Quality.allCases, id: \.self) { quality in
                            Text(quality.rawValue.capitalized).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                HStack {
                    Text("Codec")
                    Spacer()
                    Picker("Codec", selection: $viewModel.config.videoCodec) {
                        ForEach(RecordingConfig.VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue.uppercased()).tag(codec)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                HStack {
                    Text("Frame Rate")
                    Spacer()
                    Stepper("\(viewModel.config.fps) fps", value: $viewModel.config.fps, in: 15...60, step: 5)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Audio Settings

    private var audioSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio", systemImage: "mic")
                .font(.headline)

            Toggle("Microphone", isOn: $viewModel.config.enableMicrophone)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Output Settings

    private var outputSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Output", systemImage: "folder")
                .font(.headline)

            HStack {
                Text("Format")
                Spacer()
                Picker("Format", selection: $viewModel.config.outputFormat) {
                    ForEach(RecordingConfig.OutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Keyboard Shortcuts

    private func handleKeyEvent(_ event: NSEvent) {
        // Only process shortcuts while recording.
        guard viewModel.isRecording else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommand = modifiers.contains(.command)
        let isShift = modifiers.contains(.shift)
        let character = event.charactersIgnoringModifiers?.lowercased()

        // Cmd+Shift+A: toggle annotation drawing mode
        if isCommand && isShift && character == "a" {
            viewModel.toggleAnnotationDrawingMode()
            return
        }

        // Cmd+Shift+S: stop recording
        if isCommand && isShift && character == "s" {
            Task {
                await viewModel.stopRecording()
            }
            return
        }

        // Tool shortcuts (only work when annotation session is active)
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

    // MARK: - Layout Selection

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Layout", systemImage: "rectangle.split.2x1")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(RecordingLayout.allPresets, id: \.name) { layout in
                    LayoutPresetCard(layout: layout, isSelected: viewModel.config.layout.name == layout.name) {
                        viewModel.config.layout = layout
                        // Disable camera if layout has no camera, enable if it does.
                        viewModel.config.enableCamera = layout.cameraLayout.isVisible
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text(viewModel.durationString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            Spacer()

            if viewModel.isRecording {
                Button(action: {
                    Task {
                        await viewModel.stopRecording()
                    }
                }) {
                    HStack {
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
                    HStack {
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
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Layout Preset Card

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
        // Normalize to the preview's padded coordinate space.
        let padded = CGRect(x: 8, y: 8, width: containerSize.width - 16, height: containerSize.height - 16)
        return CGRect(
            x: padded.minX + rect.minX / containerSize.width * padded.width,
            y: padded.minY + rect.minY / containerSize.height * padded.height,
            width: rect.width / containerSize.width * padded.width,
            height: rect.height / containerSize.height * padded.height
        )
    }
}

// MARK: - Capture Mode Card

struct CaptureModeCard: View {
    let mode: CaptureMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.title2)
                Text(mode.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    RecordingWindow()
        .environmentObject(RecordingViewModel())
}
