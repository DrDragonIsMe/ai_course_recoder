import Foundation
import AppKit
import SwiftUI
import ScreenCaptureKit
import Combine

/// A transparent, borderless, click-through window that shows annotation strokes over the captured display.
final class AnnotationOverlayWindow: NSWindow {
    private let annotationSession: AnnotationSession
    private var trackingArea: NSTrackingArea?

    init(annotationSession: AnnotationSession) {
        self.annotationSession = annotationSession

        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.hasShadow = false

        self.contentView = AnnotationOverlayView(annotationSession: annotationSession)
    }

    /// Position the overlay to cover the given display.
    func attach(to display: SCDisplay) {
        let frame = CGDisplayBounds(display.displayID)
        setFrame(frame, display: true)
    }

    /// Show the overlay window.
    func show() {
        orderFrontRegardless()
    }

    /// Hide the overlay window.
    func hide() {
        orderOut(nil)
    }
}

// MARK: - Annotation Overlay View

private final class AnnotationOverlayView: NSView {
    private let annotationSession: AnnotationSession
    private var cancellables = Set<AnyCancellable>()

    init(annotationSession: AnnotationSession) {
        self.annotationSession = annotationSession
        super.init(frame: .zero)

        annotationSession.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.needsDisplay = true
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        annotationSession.draw(on: context)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        annotationSession.beginStroke(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        annotationSession.addPoint(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        annotationSession.finishStroke()
        needsDisplay = true
    }
}
