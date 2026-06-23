import Foundation
import AppKit
import SwiftUI
import ScreenCaptureKit
import Combine

/// A transparent, borderless overlay window that shows annotation strokes over the captured display.
/// Mouse events are ignored by default; the user toggles drawing mode with a keyboard shortcut.
final class AnnotationOverlayWindow: NSWindow {
    private let annotationSession: AnnotationSession

    /// Whether the overlay currently captures mouse events for drawing.
    private(set) var isDrawingModeEnabled = false

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
        // One level above the floating toolbar so drawing mode is never blocked.
        self.level = .init(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Ignore mouse events by default so the user can interact with apps and the toolbar.
        self.ignoresMouseEvents = true
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

    /// Toggle whether the overlay captures mouse events for annotation drawing.
    func toggleDrawingMode() {
        isDrawingModeEnabled.toggle()
        ignoresMouseEvents = !isDrawingModeEnabled
        // When drawing, keep the overlay just below the floating toolbar so toolbar buttons remain clickable.
        // When not drawing, raise it above the toolbar but ignore mouse events so it never blocks interaction.
        level = isDrawingModeEnabled
            ? .screenSaver
            : .init(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        // Bring overlay to front when entering drawing mode so it receives strokes.
        if isDrawingModeEnabled {
            orderFrontRegardless()
        }
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
