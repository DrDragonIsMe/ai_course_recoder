import SwiftUI
import AVFoundation

/// Live camera preview using AVCaptureVideoPreviewLayer.
struct PreviewView: NSViewRepresentable {
    let captureSession: AVCaptureSession?

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView()
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.captureSession = captureSession
    }
}

// MARK: - Preview NSView

final class PreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var captureSession: AVCaptureSession? {
        didSet {
            updateSession()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    private func setupLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    private func updateSession() {
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil

        guard let session = captureSession else { return }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        layer.cornerRadius = 8
        self.layer?.addSublayer(layer)
        previewLayer = layer
    }
}
