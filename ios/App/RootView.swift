import os
import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(ViewMode.storageKey) private var storedView: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardSync.self) private var sync
    @Environment(BoardsStore.self) private var boards
    @State private var clock = BoardClock()

    var body: some View {
        ZStack {
            if ViewMode(stored: storedView) == .night {
                NightBoardView()
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity)
            } else {
                BoardShell()
                    .tint(ShellTint.accent)
                    .transition(.opacity)
            }
        }
        .environment(clock)
        .environment(\.dropActions, DropActions(
            pin: { sync.setPinned($0, $1) },
            move: { sync.move($0, to: $1) },
            done: { sync.markDone($0) },
            undo: { sync.undoMove($0) },
            open: { drop in
                guard let url = drop.url.flatMap(URL.init(string:)) else {
                    Logger.app.error("drop \(drop.id.uuidString, privacy: .public) has no link to open")
                    return
                }
                openURL(url)
            }
        ))
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "BoardDebugSeed") { seed() }
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
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { storedView = mode.rawValue }
                return
            }
            #if DEBUG
            switch url.host()?.lowercased() {
            case "seed":
                Logger.app.info("loading the sample boards")
                seed()
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

    #if DEBUG
    private func seed() {
        SeedBoard.replace(in: context)
        boards.show(SeedBoard.homeBoardId)
    }
    #endif
}
