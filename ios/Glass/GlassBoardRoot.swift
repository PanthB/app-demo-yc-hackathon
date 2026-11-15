import SwiftData
import SwiftUI

struct GlassBoardRoot: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @AppStorage(ViewMode.storageKey) private var storedView: String?
    @Environment(BoardClock.self) private var clock
    @Environment(BoardsStore.self) private var boards
    @Namespace private var namespace
    @State private var selected: Drop?

    private var boardId: String {
        #if DEBUG
        if let id = UserDefaults.standard.string(forKey: "BoardDebugBoard") { return id }
        #endif
        return boards.currentBoardId
    }

    var body: some View {
        let boardId = boardId
        let isCurrent = boardId == boards.currentBoardId
        let shared = (isCurrent ? boards.currentBoard?.shared : nil) ?? (boardId != BoardKeys.personalBoard)
        let sections = DropSection.build(
            drops.filter { $0.boardId == boardId },
            grouping: shared ? .vibe : .when,
            filter: .everyone,
            me: boards.personId,
            now: clock.now
        )
        NavigationStack {
            Group {
                if ViewMode.resolve(stored: storedView) == .list {
                    ListView(sections: sections, namespace: namespace) { selected = $0 }
                } else {
                    CardsView(sections: sections, namespace: namespace) { selected = $0 }
                }
            }
            .navigationTitle(isCurrent ? boards.currentBoardName : boardId.replacingOccurrences(of: "-", with: " "))
        }
        .sheet(item: $selected) { drop in
            DropDetailView(drop: drop)
                .navigationTransition(.zoom(sourceID: drop.id, in: namespace))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .tint(Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 0.42, blue: 0.29, alpha: 1)
                : UIColor(red: 0.79, green: 0.28, blue: 0.17, alpha: 1)
        }))
    }
}
