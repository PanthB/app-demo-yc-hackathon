import os
import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(Look.storageKey) private var storedLook: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var clock = BoardClock()

    var body: some View {
        Group {
            switch Look.resolve(stored: storedLook) {
            case .paper:
                PaperBoardRoot()
            case .glass:
                GlassBoardRoot()
            }
        }
        .environment(clock)
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "BoardDebugSeed") {
                SeedBoard.replace(in: context)
            }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clock.tick() }
        }
        .task(id: clock.now) {
            let wait = ZoneClock.nextBoundary(after: clock.now).timeIntervalSince(clock.now)
            try? await Task.sleep(for: .seconds(max(wait, 1)))
            guard !Task.isCancelled else { return }
            clock.tick()
        }
        .onOpenURL { url in
            if let look = Look(url: url) {
                Logger.app.info("switching to the \(look.rawValue, privacy: .public) look")
                storedLook = look.rawValue
                return
            }
            #if DEBUG
            switch url.host()?.lowercased() {
            case "seed":
                Logger.app.info("pinning the sample board")
                SeedBoard.replace(in: context)
                return
            case "clear":
                Logger.app.info("clearing the board")
                SeedBoard.clear(context)
                return
            default:
                break
            }
            #endif
            Logger.app.error("ignored a link the app doesn't handle: \(url.absoluteString, privacy: .public)")
        }
    }
}
