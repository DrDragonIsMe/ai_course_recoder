import SwiftUI

@main
struct RecordCoursesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recordingViewModel = RecordingViewModel()

    var body: some Scene {
        WindowGroup {
            RecordingWindow()
                .environmentObject(recordingViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)

        Settings {
            SettingsPanel()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions at launch
        Task {
            await PermissionsManager.shared.checkAllPermissions()
        }
    }
}
