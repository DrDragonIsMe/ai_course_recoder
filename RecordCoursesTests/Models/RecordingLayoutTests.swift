import Testing
import Foundation
@testable import RecordCourses

@Suite("Recording Layout Tests")
struct RecordingLayoutTests {

    @Test("Layout preset returns valid screen and camera regions")
    func layoutPresetRegions() {
        let layout = RecordingLayout.presenterRight(screenSize: CGSize(width: 1920, height: 1080))
        let screenRect = layout.screenRegion.rect(for: CGSize(width: 1920, height: 1080))
        let cameraRect = layout.cameraLayout.region.rect(for: CGSize(width: 1920, height: 1080))

        #expect(screenRect.width > 0)
        #expect(screenRect.height > 0)
        #expect(cameraRect.width > 0)
        #expect(cameraRect.height > 0)
    }

    @Test("All preset names are unique")
    func presetNamesAreUnique() {
        let names = RecordingLayout.allPresets.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("Corner PIP enables camera")
    func cornerPIPHasCamera() {
        let layout = RecordingLayout.cornerPIP()
        #expect(layout.cameraLayout.isVisible == true)
    }

    @Test("Full screen layout hides camera")
    func fullScreenHidesCamera() {
        let layout = RecordingLayout.fullScreen()
        #expect(layout.cameraLayout.isVisible == false)
    }
}
