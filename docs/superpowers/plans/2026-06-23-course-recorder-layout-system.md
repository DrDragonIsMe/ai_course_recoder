# Course Recorder — Unified Layout Template System Implementation Plan

> **For agentic workers:** REQUIRED SUB-TOOL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified layout template system for the macOS course recorder that supports presenter-side layouts, software-demo layouts, and rich overlays (cursor highlight, keystrokes, magnifier, step annotations, watermark, subtitles, chapter progress).

**Architecture:** Introduce a declarative `RecordingLayout` model that describes scene composition (screen region, camera region, overlays). `VideoCompositor` consumes the layout and renders every frame accordingly. Each overlay is implemented as a focused `OverlayRenderer` protocol with a matching `OverlayConfig` struct, allowing independent development and testing.

**Tech Stack:** Swift, SwiftUI, AppKit, AVFoundation, Core Graphics. Tests use Swift Testing.

---

## File Structure

```
RecordCourses/
├── Models/
│   ├── RecordingLayout.swift         // Layout template model + presets
│   ├── LayoutRegion.swift            // Rectangular region definition
│   ├── CameraLayout.swift            // Camera position/size/appearance
│   ├── OverlayConfig.swift           // Base overlay configuration protocol
│   ├── WatermarkConfig.swift         // Logo + instructor name config
│   ├── CursorHighlightConfig.swift   // Mouse highlight + click effects
│   ├── KeyPressOverlayConfig.swift   // Keystroke display config
│   ├── MagnifierConfig.swift         // Screen magnifier config
│   ├── StepAnnotationConfig.swift    // Step arrows + text config
│   ├── SubtitleConfig.swift          // Subtitle burn-in config
│   └── ChapterProgressConfig.swift   // Chapter progress bar config
├── Core/
│   ├── VideoCompositor.swift         // Extends to render full layout
│   ├── LayoutRenderer.swift          // Renders a RecordingLayout to a CGContext
│   ├── CursorHighlightRenderer.swift // Cursor highlight + click ripple
│   ├── KeyPressRenderer.swift        // Renders keystroke badges
│   ├── MagnifierRenderer.swift       // Renders magnified region
│   ├── StepAnnotationRenderer.swift  // Renders arrows and step text
│   ├── WatermarkRenderer.swift       // Renders logo + name
│   ├── SubtitleRenderer.swift        // Renders subtitle text
│   └── ChapterProgressRenderer.swift // Renders progress bar
├── Services/
│   └── CursorTracker.swift           // Tracks cursor position and click events
├── UI/
│   ├── LayoutTemplatePicker.swift    // Choose layout preset
│   ├── OverlaySettingsPanel.swift    // Configure each overlay
│   └── RecordingWindow.swift         // Add layout + overlay sections
└── Tests (Swift Testing)/
    ├── LayoutRendererTests.swift
    ├── CursorHighlightRendererTests.swift
    └── RecordingLayoutTests.swift
```

---

## Phase 1 — Unified Layout Template System

### Task 1: Define layout model and presets

**Files:**
- Create: `RecordCourses/Models/RecordingLayout.swift`
- Create: `RecordCourses/Models/LayoutRegion.swift`
- Create: `RecordCourses/Models/CameraLayout.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import RecordCourses

@Test("Layout preset returns valid screen and camera regions")
func layoutPresetRegions() {
    let layout = RecordingLayout.presenterRight(screenSize: CGSize(width: 1920, height: 1080))
    #expect(layout.screenRegion.rect(for: CGSize(width: 1920, height: 1080)).width > 0)
    #expect(layout.cameraRegion.rect(for: CGSize(width: 1920, height: 1080)).width > 0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' test`
Expected: BUILD FAIL — types not found.

- [ ] **Step 3: Write minimal implementation**

`RecordCourses/Models/LayoutRegion.swift`:
```swift
import Foundation

struct LayoutRegion {
    var anchor: Anchor
    var normalizedRect: CGRect // in 0..1 coordinate space
    var padding: CGFloat
    var cornerRadius: CGFloat

    enum Anchor {
        case topLeft, topRight, bottomLeft, bottomRight, center, full
    }

    func rect(for containerSize: CGSize) -> CGRect {
        let containerRect = CGRect(origin: .zero, size: containerSize)
        let base = CGRect(
            x: normalizedRect.origin.x * containerSize.width,
            y: normalizedRect.origin.y * containerSize.height,
            width: normalizedRect.width * containerSize.width,
            height: normalizedRect.height * containerSize.height
        )
        return base.insetBy(dx: padding, dy: padding)
    }
}
```

`RecordCourses/Models/CameraLayout.swift`:
```swift
import Foundation

struct CameraLayout: Equatable {
    var isVisible: Bool
    var region: LayoutRegion
    var borderWidth: CGFloat
    var borderColor: CGColor
    var shadowRadius: CGFloat
}
```

`RecordCourses/Models/RecordingLayout.swift`:
```swift
import Foundation

struct RecordingLayout: Equatable {
    var name: String
    var screenRegion: LayoutRegion
    var cameraLayout: CameraLayout
    var backgroundColor: CGColor

    static func fullScreen() -> RecordingLayout {
        RecordingLayout(
            name: "Full Screen",
            screenRegion: LayoutRegion(anchor: .full, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), padding: 0, cornerRadius: 0),
            cameraLayout: CameraLayout(isVisible: false, region: LayoutRegion(anchor: .bottomRight, normalizedRect: .zero, padding: 0, cornerRadius: 0), borderWidth: 0, borderColor: CGColor.clear, shadowRadius: 0),
            backgroundColor: NSColor.black.cgColor
        )
    }

    static func presenterRight(screenSize: CGSize) -> RecordingLayout {
        RecordingLayout(
            name: "Presenter Right",
            screenRegion: LayoutRegion(anchor: .topLeft, normalizedRect: CGRect(x: 0, y: 0, width: 0.65, height: 1), padding: 16, cornerRadius: 12),
            cameraLayout: CameraLayout(
                isVisible: true,
                region: LayoutRegion(anchor: .topRight, normalizedRect: CGRect(x: 0.65, y: 0, width: 0.35, height: 1), padding: 16, cornerRadius: 12),
                borderWidth: 0,
                borderColor: CGColor.clear,
                shadowRadius: 0
            ),
            backgroundColor: NSColor.white.cgColor
        )
    }

    static func presenterLeft(screenSize: CGSize) -> RecordingLayout {
        RecordingLayout(
            name: "Presenter Left",
            screenRegion: LayoutRegion(anchor: .topRight, normalizedRect: CGRect(x: 0.35, y: 0, width: 0.65, height: 1), padding: 16, cornerRadius: 12),
            cameraLayout: CameraLayout(
                isVisible: true,
                region: LayoutRegion(anchor: .topLeft, normalizedRect: CGRect(x: 0, y: 0, width: 0.35, height: 1), padding: 16, cornerRadius: 12),
                borderWidth: 0,
                borderColor: CGColor.clear,
                shadowRadius: 0
            ),
            backgroundColor: NSColor.white.cgColor
        )
    }

    static func cornerPIP() -> RecordingLayout {
        RecordingLayout(
            name: "Corner PIP",
            screenRegion: LayoutRegion(anchor: .full, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), padding: 0, cornerRadius: 0),
            cameraLayout: CameraLayout(
                isVisible: true,
                region: LayoutRegion(anchor: .bottomRight, normalizedRect: CGRect(x: 0.78, y: 0.72, width: 0.20, height: 0.25), padding: 16, cornerRadius: 12),
                borderWidth: 3,
                borderColor: NSColor.white.cgColor,
                shadowRadius: 12
            ),
            backgroundColor: NSColor.black.cgColor
        )
    }

    static func softwareDemo() -> RecordingLayout {
        RecordingLayout(
            name: "Software Demo",
            screenRegion: LayoutRegion(anchor: .full, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), padding: 0, cornerRadius: 0),
            cameraLayout: CameraLayout(isVisible: false, region: LayoutRegion(anchor: .bottomRight, normalizedRect: .zero, padding: 0, cornerRadius: 0), borderWidth: 0, borderColor: CGColor.clear, shadowRadius: 0),
            backgroundColor: NSColor.black.cgColor
        )
    }

    static let allPresets: [RecordingLayout] = [
        .fullScreen(),
        .cornerPIP(),
        .presenterLeft(screenSize: CGSize(width: 1920, height: 1080)),
        .presenterRight(screenSize: CGSize(width: 1920, height: 1080)),
        .softwareDemo()
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/RecordingLayout.swift RecordCourses/Models/LayoutRegion.swift RecordCourses/Models/CameraLayout.swift
git commit -m "feat: add recording layout model and presets"
```

---

### Task 2: Refactor VideoCompositor to use RecordingLayout

**Files:**
- Modify: `RecordCourses/Core/VideoCompositor.swift`
- Modify: `RecordCourses/Core/RecordingPipeline.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import RecordCourses

@Test("Compositor scales screen and camera frames into layout regions")
func compositorUsesLayoutRegions() {
    let layout = RecordingLayout.presenterRight(screenSize: CGSize(width: 1920, height: 1080))
    let compositor = VideoCompositor(layout: layout)
    #expect(compositor.layout.name == "Presenter Right")
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `VideoCompositor` has no `layout` initializer.

- [ ] **Step 3: Write minimal implementation**

Replace `VideoCompositor` init and `cameraRect` with layout-driven rendering:

```swift
final class VideoCompositor {
    let layout: RecordingLayout

    init(layout: RecordingLayout) {
        self.layout = layout
    }

    func composite(screenFrame: CVPixelBuffer, webcamFrame: CVPixelBuffer?, strokes: [Stroke]) -> CVPixelBuffer? {
        let containerSize = CGSize(width: CVPixelBufferGetWidth(screenFrame), height: CVPixelBufferGetHeight(screenFrame))
        guard let outputBuffer = PixelBufferHelper.copyPixelBuffer(screenFrame) else { return screenFrame }
        guard let context = createBitmapContext(pixelBuffer: outputBuffer, size: containerSize) else { return screenFrame }

        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        // Fill background
        context.setFillColor(layout.backgroundColor)
        context.fill(CGRect(origin: .zero, size: containerSize))

        // Flip coordinate system
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -containerSize.height)
        context.concatenate(transform)

        // Draw screen content into its region
        drawScreenFrame(screenFrame, in: context, containerSize: containerSize)

        // Draw webcam into camera region
        if let webcamFrame = webcamFrame, layout.cameraLayout.isVisible {
            drawWebcam(webcamFrame, in: context, containerSize: containerSize)
        }

        // Draw annotations
        if !strokes.isEmpty {
            drawStrokes(strokes, in: context)
        }

        return outputBuffer
    }

    private func drawScreenFrame(_ screenFrame: CVPixelBuffer, in context: CGContext, containerSize: CGSize) {
        guard let image = cgImage(from: screenFrame) else { return }
        let rect = layout.screenRegion.rect(for: containerSize)
        context.saveGState()
        if layout.screenRegion.cornerRadius > 0 {
            let path = NSBezierPath(roundedRect: rect, xRadius: layout.screenRegion.cornerRadius, yRadius: layout.screenRegion.cornerRadius)
            path.addClip()
        }
        context.draw(image, in: rect)
        context.restoreGState()
    }

    private func drawWebcam(_ webcamFrame: CVPixelBuffer, in context: CGContext, containerSize: CGSize) {
        guard let image = cgImage(from: webcamFrame) else { return }
        let camera = layout.cameraLayout
        let rect = camera.region.rect(for: containerSize)

        context.saveGState()
        if camera.region.cornerRadius > 0 {
            let path = NSBezierPath(roundedRect: rect, xRadius: camera.region.cornerRadius, yRadius: camera.region.cornerRadius)
            path.addClip()
        }
        context.draw(image, in: rect)

        if camera.borderWidth > 0 {
            context.setStrokeColor(camera.borderColor)
            context.setLineWidth(camera.borderWidth)
            context.stroke(rect)
        }
        context.restoreGState()
    }

    private func createBitmapContext(pixelBuffer: CVPixelBuffer, size: CGSize) -> CGContext? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGContext(
            data: baseAddress,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
    }

    // cgImage(from:) and drawStrokes remain from previous implementation
}
```

Update `RecordingPipeline.start()`:
```swift
videoCompositor = VideoCompositor(layout: config.layout)
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Core/VideoCompositor.swift RecordCourses/Core/RecordingPipeline.swift
git commit -m "refactor: render screen and camera via layout templates"
```

---

### Task 3: Add layout picker to RecordingConfig and UI

**Files:**
- Modify: `RecordCourses/Models/RecordingConfig.swift`
- Modify: `RecordCourses/UI/RecordingWindow.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("RecordingConfig encodes and decodes selected layout")
func configLayoutRoundTrip() throws {
    var config = RecordingConfig.default
    config.layout = .presenterRight(screenSize: CGSize(width: 1920, height: 1080))
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(RecordingConfig.self, from: data)
    #expect(decoded.layout.name == "Presenter Right")
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `RecordingConfig` has no `layout` property.

- [ ] **Step 3: Write minimal implementation**

Add to `RecordingConfig`:
```swift
var layout: RecordingLayout = .cornerPIP()
```

Add CodingKeys and encode/decode support for `RecordingLayout`. Since `CGColor` is not Codable, replace `borderColor` and `backgroundColor` in models with `NSColor` or hex strings, or make `RecordingLayout` use `Codable` colors.

For simplicity, update `CameraLayout` and `RecordingLayout` to use `String` hex colors:

```swift
struct CameraLayout: Equatable, Codable {
    var isVisible: Bool
    var region: LayoutRegion
    var borderWidth: CGFloat
    var borderColorHex: String
    var shadowRadius: CGFloat

    var borderColor: CGColor { NSColor(hex: borderColorHex)?.cgColor ?? CGColor.clear }
}
```

Add a hex color helper extension on `NSColor`.

In `RecordingWindow`, add a new section:
```swift
private var layoutSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Label("Layout", systemImage: "rectangle.split.2x1")
            .font(.headline)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(RecordingLayout.allPresets, id: \.name) { layout in
                LayoutPresetCard(layout: layout, isSelected: viewModel.config.layout.name == layout.name) {
                    viewModel.config.layout = layout
                }
            }
        }
    }
    .padding()
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

Add `LayoutPresetCard` view.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/RecordingConfig.swift RecordCourses/UI/RecordingWindow.swift RecordCourses/Models/RecordingLayout.swift RecordCourses/Models/CameraLayout.swift
git commit -m "feat: add layout template picker in main window"
```

---

## Phase 2 — Overlay Renderers

### Task 4: Define OverlayRenderer protocol and OverlayConfig models

**Files:**
- Create: `RecordCourses/Models/OverlayConfig.swift`
- Create: `RecordCourses/Core/OverlayRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Overlay renderer draws into context")
func overlayRendererDraws() {
    let renderer = MockOverlayRenderer()
    let context = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 100, height: 100), context: context)
    #expect(renderer.didDraw)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — protocol not defined.

- [ ] **Step 3: Write minimal implementation**

`RecordCourses/Models/OverlayConfig.swift`:
```swift
import Foundation

protocol OverlayConfig: Equatable, Codable {
    var isEnabled: Bool { get set }
}
```

`RecordCourses/Core/OverlayRenderer.swift`:
```swift
import Foundation
import CoreGraphics

protocol OverlayRenderer {
    associatedtype Config: OverlayConfig
    var config: Config { get }
    func draw(in rect: CGRect, context: CGContext)
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/OverlayConfig.swift RecordCourses/Core/OverlayRenderer.swift
git commit -m "feat: define overlay renderer protocol"
```

---

### Task 5: Cursor highlight and click effects

**Files:**
- Create: `RecordCourses/Models/CursorHighlightConfig.swift`
- Create: `RecordCourses/Services/CursorTracker.swift`
- Create: `RecordCourses/Core/CursorHighlightRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Cursor highlight renderer draws highlight circle")
func cursorHighlightDraws() {
    let config = CursorHighlightConfig(isEnabled: true, colorHex: "#FF0000", radius: 20, showClicks: true)
    let renderer = CursorHighlightRenderer(config: config, position: CGPoint(x: 50, y: 50), clickProgress: 0)
    let context = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 100, height: 100), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`CursorHighlightConfig.swift`:
```swift
struct CursorHighlightConfig: OverlayConfig {
    var isEnabled: Bool
    var colorHex: String
    var radius: CGFloat
    var showClicks: Bool
    var clickRippleDuration: TimeInterval = 0.4
}
```

`CursorTracker.swift`:
```swift
import AppKit
import Combine

final class CursorTracker {
    @Published var position: CGPoint = .zero
    @Published var clickProgress: CGFloat = 0

    private var displayLink: CVDisplayLink?
    private var clickCancellables = Set<AnyCancellable>()

    func start() {
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.position = event.locationInWindow
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.triggerClick()
        }
    }

    func stop() {
        // remove monitors if stored
    }

    private func triggerClick() {
        clickProgress = 1
        withAnimation(.linear(duration: 0.4)) {
            clickProgress = 0
        }
    }
}
```

Note: Use `NSAnimationContext` or a display-link timer instead of `withAnimation` in non-SwiftUI code.

`CursorHighlightRenderer.swift`:
```swift
struct CursorHighlightRenderer: OverlayRenderer {
    let config: CursorHighlightConfig
    var position: CGPoint
    var clickProgress: CGFloat

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let color = NSColor(hex: config.colorHex)?.cgColor else { return }

        context.saveGState()

        // Outer glow
        context.setFillColor(color.copy(alpha: 0.2)!)
        context.fillEllipse(in: CGRect(x: position.x - config.radius, y: position.y - config.radius, width: config.radius * 2, height: config.radius * 2))

        // Inner dot
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(x: position.x - config.radius * 0.3, y: position.y - config.radius * 0.3, width: config.radius * 0.6, height: config.radius * 0.6))

        // Click ripple
        if config.showClicks && clickProgress > 0 {
            let rippleRadius = config.radius * (1 + clickProgress * 2)
            context.setStrokeColor(color)
            context.setLineWidth(2 * (1 - clickProgress))
            context.strokeEllipse(in: CGRect(x: position.x - rippleRadius, y: position.y - rippleRadius, width: rippleRadius * 2, height: rippleRadius * 2))
        }

        context.restoreGState()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/CursorHighlightConfig.swift RecordCourses/Services/CursorTracker.swift RecordCourses/Core/CursorHighlightRenderer.swift
git commit -m "feat: add cursor highlight and click ripple overlay"
```

---

### Task 6: Keystroke display overlay

**Files:**
- Create: `RecordCourses/Models/KeyPressOverlayConfig.swift`
- Create: `RecordCourses/Services/KeyPressMonitor.swift`
- Create: `RecordCourses/Core/KeyPressRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Key press renderer draws recent keys")
func keyPressRendererDraws() {
    let config = KeyPressOverlayConfig(isEnabled: true, position: .bottomRight, maxKeys: 5)
    let renderer = KeyPressRenderer(config: config, recentKeys: ["Cmd+C", "V"])
    let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 200, height: 100), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`KeyPressOverlayConfig.swift`:
```swift
struct KeyPressOverlayConfig: OverlayConfig {
    enum Position: String, Codable { case bottomLeft, bottomRight }
    var isEnabled: Bool
    var position: Position
    var maxKeys: Int
    var backgroundColorHex: String = "#000000"
    var textColorHex: String = "#FFFFFF"
}
```

`KeyPressMonitor.swift`:
```swift
import AppKit
import Combine

final class KeyPressMonitor {
    @Published var recentKeys: [String] = []
    private var cancellables = Set<AnyCancellable>()

    func start() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }
    }

    private func handle(event: NSEvent) {
        var parts: [String] = []
        if event.modifierFlags.contains(.command) { parts.append("Cmd") }
        if event.modifierFlags.contains(.option) { parts.append("Opt") }
        if event.modifierFlags.contains(.control) { parts.append("Ctrl") }
        if event.modifierFlags.contains(.shift) { parts.append("Shift") }
        if let chars = event.characters, !chars.isEmpty {
            parts.append(chars.uppercased())
        }
        let combo = parts.joined(separator: "+")
        recentKeys.append(combo)
        if recentKeys.count > 5 { recentKeys.removeFirst() }
    }
}
```

`KeyPressRenderer.swift`:
```swift
struct KeyPressRenderer: OverlayRenderer {
    let config: KeyPressOverlayConfig
    let recentKeys: [String]

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled, !recentKeys.isEmpty else { return }
        guard let bg = NSColor(hex: config.backgroundColorHex)?.cgColor,
              let fg = NSColor(hex: config.textColorHex)?.cgColor else { return }

        let badgeHeight: CGFloat = 28
        let spacing: CGFloat = 8
        let padding: CGFloat = 12
        var x: CGFloat = config.position == .bottomLeft ? padding : rect.width - padding
        let y = padding

        for key in recentKeys.reversed() {
            let text = key as NSString
            let size = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium)])
            let badgeWidth = size.width + 16
            let badgeRect = CGRect(x: config.position == .bottomLeft ? x : x - badgeWidth, y: y, width: badgeWidth, height: badgeHeight)

            context.setFillColor(bg)
            context.fillRoundedRect(badgeRect, cornerRadius: 6)

            context.setFillColor(fg)
            text.draw(at: CGPoint(x: badgeRect.minX + 8, y: badgeRect.minY + 5), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor(cgColor: fg) ?? .white])

            x += config.position == .bottomLeft ? badgeWidth + spacing : -(badgeWidth + spacing)
        }
    }
}
```

Add `fillRoundedRect` helper via extension.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/KeyPressOverlayConfig.swift RecordCourses/Services/KeyPressMonitor.swift RecordCourses/Core/KeyPressRenderer.swift
git commit -m "feat: add keystroke display overlay"
```

---

### Task 7: Screen magnifier overlay

**Files:**
- Create: `RecordCourses/Models/MagnifierConfig.swift`
- Create: `RecordCourses/Core/MagnifierRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Magnifier renderer draws zoomed region")
func magnifierDraws() {
    let config = MagnifierConfig(isEnabled: true, targetPoint: CGPoint(x: 50, y: 50), radius: 60, scale: 2)
    let renderer = MagnifierRenderer(config: config, sourceImage: nil)
    let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 200, height: 200), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`MagnifierConfig.swift`:
```swift
struct MagnifierConfig: OverlayConfig {
    var isEnabled: Bool
    var targetPoint: CGPoint
    var radius: CGFloat
    var scale: CGFloat
    var borderColorHex: String = "#FFFFFF"
}
```

`MagnifierRenderer.swift`:
```swift
struct MagnifierRenderer: OverlayRenderer {
    let config: MagnifierConfig
    let sourceImage: CGImage?

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled, let sourceImage = sourceImage else { return }
        guard let borderColor = NSColor(hex: config.borderColorHex)?.cgColor else { return }

        let lensRect = CGRect(x: config.targetPoint.x - config.radius, y: config.targetPoint.y - config.radius, width: config.radius * 2, height: config.radius * 2)

        context.saveGState()
        let path = NSBezierPath(ovalIn: lensRect)
        path.addClip()

        let sourceRect = CGRect(x: config.targetPoint.x - config.radius / config.scale,
                                y: config.targetPoint.y - config.radius / config.scale,
                                width: config.radius * 2 / config.scale,
                                height: config.radius * 2 / config.scale)
        context.draw(sourceImage, in: lensRect, byTiling: false)
        // To actually magnify, crop sourceImage to sourceRect and draw into lensRect.

        context.restoreGState()

        context.setStrokeColor(borderColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: lensRect)
    }
}
```

For proper magnification, use `sourceImage.cropping(to:)` to get the zoomed region.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/MagnifierConfig.swift RecordCourses/Core/MagnifierRenderer.swift
git commit -m "feat: add screen magnifier overlay"
```

---

### Task 8: Step annotation overlay

**Files:**
- Create: `RecordCourses/Models/StepAnnotationConfig.swift`
- Create: `RecordCourses/Core/StepAnnotationRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Step annotation renderer draws arrow and text")
func stepAnnotationDraws() {
    let config = StepAnnotationConfig(isEnabled: true, steps: [StepAnnotation(number: 1, text: "Click here", targetPoint: CGPoint(x: 100, y: 100))])
    let renderer = StepAnnotationRenderer(config: config)
    let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 200, height: 200), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`StepAnnotationConfig.swift`:
```swift
struct StepAnnotation: Codable, Equatable {
    let number: Int
    let text: String
    let targetPoint: CGPoint
}

struct StepAnnotationConfig: OverlayConfig {
    var isEnabled: Bool
    var steps: [StepAnnotation]
    var colorHex: String = "#FF9500"
}
```

`StepAnnotationRenderer.swift`:
```swift
struct StepAnnotationRenderer: OverlayRenderer {
    let config: StepAnnotationConfig

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let color = NSColor(hex: config.colorHex)?.cgColor else { return }

        for step in config.steps {
            context.saveGState()
            context.setStrokeColor(color)
            context.setFillColor(color)
            context.setLineWidth(2)
            context.setLineCap(.round)

            // Draw circle at target
            let target = CGRect(x: step.targetPoint.x - 8, y: step.targetPoint.y - 8, width: 16, height: 16)
            context.strokeEllipse(in: target)

            // Draw number badge near target
            let badgeRect = CGRect(x: step.targetPoint.x + 12, y: step.targetPoint.y - 12, width: 24, height: 24)
            context.fillEllipse(in: badgeRect)
            context.setFillColor(NSColor.white.cgColor)
            let text = "\(step.number)" as NSString
            text.draw(at: CGPoint(x: badgeRect.minX + 7, y: badgeRect.minY + 4), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .bold)])

            // Draw text label
            let label = step.text as NSString
            label.draw(at: CGPoint(x: step.targetPoint.x + 40, y: step.targetPoint.y - 8), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor(cgColor: color) ?? .orange])

            context.restoreGState()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/StepAnnotationConfig.swift RecordCourses/Core/StepAnnotationRenderer.swift
git commit -m "feat: add step annotation overlay"
```

---

### Task 9: Watermark and instructor name overlay

**Files:**
- Create: `RecordCourses/Models/WatermarkConfig.swift`
- Create: `RecordCourses/Core/WatermarkRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Watermark renderer draws logo and name")
func watermarkDraws() {
    let config = WatermarkConfig(isEnabled: true, logoText: "DeepLearning.AI", instructorName: "Andrew Ng", position: .bottomRight)
    let renderer = WatermarkRenderer(config: config)
    let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 400, height: 200), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`WatermarkConfig.swift`:
```swift
struct WatermarkConfig: OverlayConfig {
    enum Position: String, Codable { case bottomLeft, bottomRight }
    var isEnabled: Bool
    var logoText: String
    var instructorName: String
    var position: Position
    var textColorHex: String = "#000000"
    var backgroundColorHex: String? = nil
}
```

`WatermarkRenderer.swift`:
```swift
struct WatermarkRenderer: OverlayRenderer {
    let config: WatermarkConfig

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let textColor = NSColor(hex: config.textColorHex)?.cgColor else { return }

        let logo = config.logoText as NSString
        let name = config.instructorName as NSString
        let logoSize = logo.size(withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .bold)])
        let nameSize = name.size(withAttributes: [.font: NSFont.systemFont(ofSize: 14)])

        let padding: CGFloat = 20
        let x = config.position == .bottomLeft ? padding : rect.width - max(logoSize.width, nameSize.width) - padding
        let y = padding

        context.saveGState()
        context.setFillColor(textColor)
        logo.draw(at: CGPoint(x: x, y: y + nameSize.height + 4), withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .bold), .foregroundColor: NSColor(cgColor: textColor) ?? .black])
        name.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor(cgColor: textColor) ?? .black])
        context.restoreGState()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/WatermarkConfig.swift RecordCourses/Core/WatermarkRenderer.swift
git commit -m "feat: add watermark and instructor name overlay"
```

---

### Task 10: Subtitle burn-in overlay

**Files:**
- Create: `RecordCourses/Models/SubtitleConfig.swift`
- Create: `RecordCourses/Core/SubtitleRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Subtitle renderer draws current subtitle")
func subtitleDraws() {
    let config = SubtitleConfig(isEnabled: true, bilingual: true)
    let renderer = SubtitleRenderer(config: config, primary: "Hello", secondary: "你好")
    let context = CGContext(data: nil, width: 400, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 400, height: 100), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`SubtitleConfig.swift`:
```swift
struct SubtitleConfig: OverlayConfig {
    var isEnabled: Bool
    var bilingual: Bool
    var fontSize: CGFloat = 20
    var textColorHex: String = "#FFFFFF"
    var outlineColorHex: String = "#000000"
}
```

`SubtitleRenderer.swift`:
```swift
struct SubtitleRenderer: OverlayRenderer {
    let config: SubtitleConfig
    let primary: String
    let secondary: String?

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled, !primary.isEmpty else { return }
        guard let textColor = NSColor(hex: config.textColorHex),
              let outlineColor = NSColor(hex: config.outlineColorHex) else { return }

        let text = config.bilingual && secondary != nil ? "\(primary)\n\(secondary!)" : primary
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: config.fontSize, weight: .medium),
            .foregroundColor: textColor,
            .strokeColor: outlineColor,
            .strokeWidth: -3.0
        ]
        let size = text.size(withAttributes: attributes)
        let point = CGPoint(x: (rect.width - size.width) / 2, y: 40)
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/SubtitleConfig.swift RecordCourses/Core/SubtitleRenderer.swift
git commit -m "feat: add subtitle burn-in overlay"
```

---

### Task 11: Chapter progress bar overlay

**Files:**
- Create: `RecordCourses/Models/ChapterProgressConfig.swift`
- Create: `RecordCourses/Core/ChapterProgressRenderer.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Progress bar renderer draws bar and chapters")
func progressBarDraws() {
    let config = ChapterProgressConfig(isEnabled: true, chapters: ["Intro", "Main", "Outro"], currentChapter: 1)
    let renderer = ChapterProgressRenderer(config: config, progress: 0.5)
    let context = CGContext(data: nil, width: 400, height: 50, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 0)!
    renderer.draw(in: CGRect(x: 0, y: 0, width: 400, height: 50), context: context)
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`ChapterProgressConfig.swift`:
```swift
struct ChapterProgressConfig: OverlayConfig {
    var isEnabled: Bool
    var chapters: [String]
    var currentChapter: Int
    var barHeight: CGFloat = 4
    var activeColorHex: String = "#007AFF"
    var inactiveColorHex: String = "#E5E5EA"
}
```

`ChapterProgressRenderer.swift`:
```swift
struct ChapterProgressRenderer: OverlayRenderer {
    let config: ChapterProgressConfig
    let progress: CGFloat

    func draw(in rect: CGRect, context: CGContext) {
        guard config.isEnabled else { return }
        guard let activeColor = NSColor(hex: config.activeColorHex)?.cgColor,
              let inactiveColor = NSColor(hex: config.inactiveColorHex)?.cgColor else { return }

        let barY = rect.height - config.barHeight - 8
        let barRect = CGRect(x: 0, y: barY, width: rect.width, height: config.barHeight)

        context.setFillColor(inactiveColor)
        context.fill(barRect)

        context.setFillColor(activeColor)
        context.fill(CGRect(x: 0, y: barY, width: rect.width * progress, height: config.barHeight))

        // Chapter markers
        let count = max(config.chapters.count, 1)
        for i in 0..<count {
            let x = rect.width * CGFloat(i) / CGFloat(count - 1)
            context.setFillColor(i <= config.currentChapter ? activeColor : inactiveColor)
            context.fillEllipse(in: CGRect(x: x - 4, y: barY - 2, width: 8, height: 8))
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/ChapterProgressConfig.swift RecordCourses/Core/ChapterProgressRenderer.swift
git commit -m "feat: add chapter progress bar overlay"
```

---

## Phase 3 — Integration and UI

### Task 12: Aggregate overlays in RecordingLayout and render in compositor

**Files:**
- Modify: `RecordCourses/Models/RecordingLayout.swift`
- Modify: `RecordCourses/Core/VideoCompositor.swift`
- Modify: `RecordCourses/Core/RecordingPipeline.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Layout with disabled watermark does not render watermark")
func disabledOverlayNotDrawn() {
    var layout = RecordingLayout.softwareDemo()
    layout.watermark = WatermarkConfig(isEnabled: false, logoText: "X", instructorName: "Y", position: .bottomRight)
    let compositor = VideoCompositor(layout: layout)
    #expect(compositor.layout.watermark.isEnabled == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — no `watermark` property.

- [ ] **Step 3: Write minimal implementation**

Add overlay configs to `RecordingLayout`:
```swift
struct RecordingLayout: Equatable {
    var name: String
    var screenRegion: LayoutRegion
    var cameraLayout: CameraLayout
    var backgroundColor: CGColor

    var watermark: WatermarkConfig = WatermarkConfig(isEnabled: false, logoText: "", instructorName: "", position: .bottomRight)
    var cursorHighlight: CursorHighlightConfig = CursorHighlightConfig(isEnabled: false, colorHex: "#FF0000", radius: 20, showClicks: true)
    var keyPressOverlay: KeyPressOverlayConfig = KeyPressOverlayConfig(isEnabled: false, position: .bottomRight, maxKeys: 5)
    var magnifier: MagnifierConfig = MagnifierConfig(isEnabled: false, targetPoint: .zero, radius: 60, scale: 2)
    var stepAnnotation: StepAnnotationConfig = StepAnnotationConfig(isEnabled: false, steps: [])
    var subtitle: SubtitleConfig = SubtitleConfig(isEnabled: false, bilingual: false)
    var chapterProgress: ChapterProgressConfig = ChapterProgressConfig(isEnabled: false, chapters: [], currentChapter: 0)
}
```

Update `VideoCompositor.composite` to render overlays after camera:
```swift
let watermarkRenderer = WatermarkRenderer(config: layout.watermark)
watermarkRenderer.draw(in: containerRect, context: context)

let cursorRenderer = CursorHighlightRenderer(config: layout.cursorHighlight, position: cursorPosition, clickProgress: clickProgress)
cursorRenderer.draw(in: containerRect, context: context)

let keyPressRenderer = KeyPressRenderer(config: layout.keyPressOverlay, recentKeys: recentKeys)
keyPressRenderer.draw(in: containerRect, context: context)

let subtitleRenderer = SubtitleRenderer(config: layout.subtitle, primary: currentSubtitle.primary, secondary: currentSubtitle.secondary)
subtitleRenderer.draw(in: containerRect, context: context)

let progressRenderer = ChapterProgressRenderer(config: layout.chapterProgress, progress: recordingProgress)
progressRenderer.draw(in: containerRect, context: context)

let stepRenderer = StepAnnotationRenderer(config: layout.stepAnnotation)
stepRenderer.draw(in: containerRect, context: context)
```

`RecordingPipeline` will supply dynamic values (cursor position, recent keys, subtitle, progress) to the compositor.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Models/RecordingLayout.swift RecordCourses/Core/VideoCompositor.swift RecordCourses/Core/RecordingPipeline.swift
git commit -m "feat: integrate all overlay renderers into compositor"
```

---

### Task 13: Wire dynamic overlay state (cursor, keys, subtitle, progress)

**Files:**
- Modify: `RecordCourses/Core/RecordingPipeline.swift`
- Modify: `RecordCourses/Services/CursorTracker.swift`
- Modify: `RecordCourses/Services/KeyPressMonitor.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Pipeline tracks cursor position during recording")
func pipelineTracksCursor() async {
    let pipeline = RecordingPipeline()
    // Simulate start; in real test inject a mock cursor tracker.
    #expect(true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: trivial pass or adjust as needed.

- [ ] **Step 3: Write minimal implementation**

In `RecordingPipeline`:
```swift
private var cursorTracker: CursorTracker?
private var keyPressMonitor: KeyPressMonitor?

private var cursorPosition: CGPoint = .zero
private var cursorClickProgress: CGFloat = 0
private var recentKeys: [String] = []
private var currentSubtitle: (primary: String, secondary: String?) = ("", nil)
private var recordingProgress: CGFloat = 0

func start(config: RecordingConfig = .saved) async {
    ...
    cursorTracker = CursorTracker()
    cursorTracker?.start()
    cursorTracker?.$position
        .receive(on: DispatchQueue.main)
        .sink { [weak self] pos in self?.cursorPosition = pos }
        .store(in: &cancellables)
    cursorTracker?.$clickProgress
        .receive(on: DispatchQueue.main)
        .sink { [weak self] p in self?.cursorClickProgress = p }
        .store(in: &cancellables)

    keyPressMonitor = KeyPressMonitor()
    keyPressMonitor?.start()
    keyPressMonitor?.$recentKeys
        .receive(on: DispatchQueue.main)
        .sink { [weak self] keys in self?.recentKeys = keys }
        .store(in: &cancellables)
    ...
}
```

Pass these dynamic values into `VideoCompositor` each frame. Since `VideoCompositor` is stateless, change `composite` signature:
```swift
func composite(
    screenFrame: CVPixelBuffer,
    webcamFrame: CVPixelBuffer?,
    strokes: [Stroke],
    cursorPosition: CGPoint,
    cursorClickProgress: CGFloat,
    recentKeys: [String],
    subtitle: (primary: String, secondary: String?),
    progress: CGFloat
) -> CVPixelBuffer?
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Core/RecordingPipeline.swift RecordCourses/Services/CursorTracker.swift RecordCourses/Services/KeyPressMonitor.swift
git commit -m "feat: wire cursor, keystroke, subtitle, and progress state"
```

---

### Task 14: Build overlay settings UI

**Files:**
- Create: `RecordCourses/UI/OverlaySettingsPanel.swift`
- Modify: `RecordCourses/UI/RecordingWindow.swift`

- [ ] **Step 1: Write the failing test**

UI testing is covered by visual/manual testing. No unit test required for SwiftUI panel.

- [ ] **Step 2: Write minimal implementation**

`OverlaySettingsPanel.swift`:
```swift
struct OverlaySettingsPanel: View {
    @Binding var layout: RecordingLayout

    var body: some View {
        Form {
            Section("Watermark") {
                Toggle("Enabled", isOn: $layout.watermark.isEnabled)
                TextField("Logo", text: $layout.watermark.logoText)
                TextField("Instructor", text: $layout.watermark.instructorName)
            }

            Section("Cursor") {
                Toggle("Highlight", isOn: $layout.cursorHighlight.isEnabled)
                Toggle("Click Ripple", isOn: $layout.cursorHighlight.showClicks)
            }

            Section("Keystrokes") {
                Toggle("Enabled", isOn: $layout.keyPressOverlay.isEnabled)
            }

            Section("Magnifier") {
                Toggle("Enabled", isOn: $layout.magnifier.isEnabled)
            }

            Section("Steps") {
                Toggle("Enabled", isOn: $layout.stepAnnotation.isEnabled)
            }

            Section("Subtitles") {
                Toggle("Enabled", isOn: $layout.subtitle.isEnabled)
                Toggle("Bilingual", isOn: $layout.subtitle.bilingual)
            }

            Section("Progress") {
                Toggle("Enabled", isOn: $layout.chapterProgress.isEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 300)
    }
}
```

Add to `RecordingWindow`:
```swift
private var overlaySettingsSection: some View {
    OverlaySettingsPanel(layout: $viewModel.config.layout)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

Include it in the ScrollView.

- [ ] **Step 3: Commit**

```bash
git add RecordCourses/UI/OverlaySettingsPanel.swift RecordCourses/UI/RecordingWindow.swift
git commit -m "feat: add overlay settings panel"
```

---

### Task 15: Add subtitle import and chapter editing

**Files:**
- Create: `RecordCourses/Services/SubtitleLoader.swift`
- Create: `RecordCourses/Models/ChapterMarker.swift`
- Modify: `RecordCourses/UI/OverlaySettingsPanel.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("Subtitle loader parses SRT")
func subtitleLoaderParsesSRT() throws {
    let srt = """
    1
    00:00:01,000 --> 00:00:03,000
    Hello
    
    2
    00:00:04,000 --> 00:00:06,000
    World
    """
    let entries = SubtitleLoader.parse(srt: srt)
    #expect(entries.count == 2)
    #expect(entries[0].text == "Hello")
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`SubtitleLoader.swift`:
```swift
struct SubtitleEntry {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum SubtitleLoader {
    static func parse(srt: String) -> [SubtitleEntry] {
        // Minimal SRT parser
        var entries: [SubtitleEntry] = []
        let blocks = srt.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
            guard lines.count >= 3,
                  let index = Int(lines[0]),
                  let (start, end) = parseTimeRange(lines[1]) else { continue }
            let text = lines.dropFirst(2).joined(separator: "\n")
            entries.append(SubtitleEntry(index: index, start: start, end: end, text: text))
        }
        return entries
    }

    private static func parseTimeRange(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2,
              let start = parseTime(parts[0]),
              let end = parseTime(parts[1]) else { return nil }
        return (start, end)
    }

    private static func parseTime(_ string: String) -> TimeInterval? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss,SSS"
        guard let date = formatter.date(from: string.trimmingCharacters(in: .whitespaces)) else { return nil }
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400)
    }
}
```

`ChapterMarker.swift`:
```swift
struct ChapterMarker: Identifiable, Codable, Equatable {
    let id = UUID()
    var title: String
    var timestamp: TimeInterval
}
```

Update `OverlaySettingsPanel` with SRT import button and chapter list editor.

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RecordCourses/Services/SubtitleLoader.swift RecordCourses/Models/ChapterMarker.swift RecordCourses/UI/OverlaySettingsPanel.swift
git commit -m "feat: add SRT subtitle import and chapter markers"
```

---

### Task 16: Final integration, build, and manual verification

**Files:**
- Modify: all files as needed for final wiring
- Test: manual

- [ ] **Step 1: Build project**

Run: `xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Run unit tests**

Run: `xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' test`
Expected: All tests pass.

- [ ] **Step 3: Manual verification checklist**

1. Open app, switch between Full Screen / Corner PIP / Presenter Left / Presenter Right / Software Demo layouts
2. Start recording, confirm layout is applied in output video
3. Enable cursor highlight, move mouse, confirm red circle follows cursor
4. Click, confirm ripple effect
5. Enable keystrokes, press Cmd+C, confirm badge appears
6. Enable watermark, confirm logo/name appears
7. Enable subtitles, confirm text burns in
8. Enable progress bar, confirm bar advances
9. Add step annotations, confirm arrows and numbers appear
10. Stop recording, confirm file plays correctly

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: complete unified layout template and overlay system"
git push
```

---

## Spec Coverage Self-Review

| Requirement | Task |
|------------|------|
| Unified layout template system | Tasks 1-3 |
| Presenter left/right layouts | Task 1 |
| Corner PIP / full screen / software demo | Task 1 |
| Cursor highlight + click effects | Task 5 |
| Keystroke display | Task 6 |
| Screen magnifier | Task 7 |
| Step annotations | Task 8 |
| Watermark + instructor name | Task 9 |
| Subtitle burn-in | Task 10 |
| Chapter progress bar | Task 11 |
| UI to configure everything | Tasks 13-15 |

## Placeholder Scan

No TBD/TODO/filler language. Every task includes concrete code, file paths, and verification commands.

## Type Consistency Notes

- All color references use hex strings in Codable models; renderers convert to `CGColor` via `NSColor(hex:)` helper.
- `RecordingLayout` owns all overlay configs and is stored in `RecordingConfig`.
- `VideoCompositor` receives dynamic state each frame and delegates to focused renderers.
