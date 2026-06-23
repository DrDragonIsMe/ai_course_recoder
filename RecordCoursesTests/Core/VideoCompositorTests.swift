import Testing
import Foundation
@testable import RecordCourses

@Suite("Video Compositor Tests")
struct VideoCompositorTests {

    @Test("Compositor accepts a layout")
    func compositorUsesLayout() {
        let layout = RecordingLayout.presenterRight(screenSize: CGSize(width: 1920, height: 1080))
        let compositor = VideoCompositor(layout: layout)
        #expect(compositor.layout.name == "Presenter Right")
    }

    @Test("Software demo layout hides camera")
    func softwareDemoHidesCamera() {
        let layout = RecordingLayout.softwareDemo()
        let compositor = VideoCompositor(layout: layout)
        #expect(compositor.layout.cameraLayout.isVisible == false)
    }
}
