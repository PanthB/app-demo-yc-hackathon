import os
import SwiftData
import SwiftUI

struct DropPipeline: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var sync = BoardSync(boards: BoardsStore())

    func body(content: Content) -> some View {
        @Bindable var boards = sync.boards
        content
            .environment(sync)
            .environment(sync.boards)
            .onAppear { sync.wake(in: context) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { sync.wake(in: context) }
            }
            .onOpenURL { url in
                #if DEBUG
                if url.host() == "debug", ["hold-share-note", "release-share-note"].contains(url.lastPathComponent) {
                    let holds = url.lastPathComponent == "hold-share-note"
                    AppGroup.defaults.set(holds, forKey: "holdShareNote")
                    Logger.sync.info("the share note \(holds ? "now stays until it's tapped" : "closes by itself again", privacy: .public)")
                    return
                }
                #endif
                guard let code = BoardsStore.inviteCode(in: url) else { return }
                Logger.sync.info("opened an invite to a board")
                boards.entry = .join(code: code)
            }
            .sheet(item: $boards.entry) { entry in
                BoardEntrySheet(entry: entry)
                    .environment(sync.boards)
            }
    }
}

extension View {
    func dropPipeline() -> some View {
        modifier(DropPipeline())
    }
}
