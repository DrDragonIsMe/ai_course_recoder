import SwiftUI
import AppKit
import Combine

/// Always-on-top floating toolbar for recording controls.
final class FloatingToolbarWindow: NSPanel {
    private let viewModel: RecordingViewModel
    private var hostingView: NSView?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: RecordingViewModel) {
        self.viewModel = viewModel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.worksWhenModal = true
        self.hidesOnDeactivate = false

        setupContent()
        observeViewModel()
        centerOnScreen()
    }

    private func setupContent() {
        let contentView = NSHostingView(rootView: FloatingToolbarContent(viewModel: viewModel))
        self.contentView = contentView
    }

    private func observeViewModel() {
        viewModel.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if isRecording {
                    self?.orderFrontRegardless()
                } else {
                    self?.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - windowFrame.height - 16
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Toolbar Content

struct FloatingToolbarContent: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        HStack(spacing: 16) {
            recordingIndicator

            Spacer()

            Text(viewModel.durationString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            Button(action: {
                Task {
                    if viewModel.isRecording {
                        await viewModel.stopRecording()
                    } else {
                        await viewModel.startRecording()
                    }
                }
            }) {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "record.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.isRecording ? .red : .white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.85))
        .clipShape(Capsule())
        .shadow(radius: 12)
    }

    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(viewModel.isRecording ? 1 : 0.4)
            Text(viewModel.isRecording ? "REC" : "Ready")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }
}
