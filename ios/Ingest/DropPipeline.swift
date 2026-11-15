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
