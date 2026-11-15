import SwiftData
import SwiftUI

@main
struct AppDemoApp: App {
    private let container = BoardStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .dropPipeline()
        }
        .modelContainer(container)
    }
}
