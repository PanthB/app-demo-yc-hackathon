import os
import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(ViewMode.storageKey) private var storedView: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var clock = BoardClock()

    var body: some View {
        Group {
            switch ViewMode.resolve(stored: storedView) {
            case .board:
                PaperBoardRoot()
            case .cards, .list:
                GlassBoardRoot()
            }
        }
        .environment(clock)
        .environment(\.dropActions, DropActions(open: { drop in
            guard let url = drop.url.flatMap(URL.init(string:)) else {
                Logger.app.error("drop \(drop.id.uuidString, privacy: .public) has no link to open")
                return
            }
            openURL(url)
        }))
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
            if let mode = ViewMode(url: url) {
                Logger.app.info("switching to the \(mode.rawValue, privacy: .public) view")
                storedView = mode.rawValue
                return
            }
            #if DEBUG
            switch url.host()?.lowercased() {
            case "seed":
                Logger.app.info("loading the sf crew sample board")
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
