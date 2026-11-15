import SwiftData
import SwiftUI

@main
struct AppDemoApp: App {
    private let container = BoardStore.makeContainer()

    init() {
        let defaults = UserDefaults.standard
        defaults.set(ViewMode.resolve(stored: defaults.string(forKey: ViewMode.storageKey)).rawValue, forKey: ViewMode.storageKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .cameraDebugLauncher()
                .dropPipeline()
        }
        .modelContainer(container)
    }
}
