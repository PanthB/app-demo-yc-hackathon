import SwiftData
import SwiftUI

struct BoardShell: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @AppStorage(ViewMode.storageKey) private var storedView: String?
    @AppStorage(Mood.handwritingKey) private var handwriting = true
    @Environment(BoardsStore.self) private var boards
    @Environment(BoardClock.self) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace
    @State private var path: [Drop] = []
    @State private var filter: DropFilter = .everyone
    @State private var groupings: [String: DropGrouping] = [:]
    @State private var showsMembers = false

    var body: some View {
        let mode = ViewMode(stored: storedView)
        let known = knownBoards
        let boardId = boards.currentBoardId
        let board = known.first { $0.boardId == boardId }
        let title = board?.name ?? boards.currentBoardName
        let shared = board?.shared ?? false
        let grouping = groupings[boardId] ?? (shared ? .vibe : .when)
        let me = boards.personId
        let onBoard = drops.filter { $0.boardId == boardId || (!shared && $0.boardId.isEmpty) }
        let sections = DropSection.build(onBoard, grouping: grouping, filter: filter, me: me, now: clock.now)

        NavigationStack(path: $path) {
            content(mode: mode, grouping: grouping, sections: sections, drops: onBoard, me: me)
                .id(mode)
                .transition(.opacity)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarTitleMenu { boardMenu(known, current: boardId) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("arrange", selection: Binding(
                                get: { grouping },
                                set: { groupings[boardId] = $0 }
                            )) {
                                ForEach(DropGrouping.allCases, id: \.self) { choice in
                                    Text(choice.menuName).tag(choice)
                                }
                            }
                            if mode == .board, grouping == .when {
                                Toggle("handwritten notes", isOn: $handwriting)
                            }
                        } label: {
                            Label("arrange", systemImage: "rectangle.3.group")
                        }
                        .accessibilityIdentifier("arrangeMenu")
                    }
                    if let board, shared {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showsMembers = true
                            } label: {
                                ShellMemberStack(members: board.members)
                            }
                            .accessibilityLabel("people in \(board.name)")
                            .accessibilityIdentifier("membersButton")
                        }
                    }
                }
                .safeAreaBar(edge: .top) {
                    if shared {
                        Picker("show", selection: $filter) {
                            Text("everyone").tag(DropFilter.everyone)
                            Text("mine").tag(DropFilter.mine)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .accessibilityIdentifier("filterControl")
                    }
                }
                .safeAreaBar(edge: .bottom) {
                    ShellBar(mode: mode) { next in
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { storedView = next.rawValue }
                    }
                }
                .navigationDestination(for: Drop.self) { drop in
                    DropDetailView(drop: drop)
                        .navigationTransition(.zoom(sourceID: drop.id, in: namespace))
                }
        }
        .animation(reduceMotion ? nil : .smooth, value: filter)
        .animation(reduceMotion ? nil : .smooth, value: grouping)
        .sheet(isPresented: $showsMembers) {
            if let board {
                ShellMembersSheet(board: board)
            }
        }
    }

    @ViewBuilder
    private func content(mode: ViewMode, grouping: DropGrouping, sections: [DropSection], drops: [Drop], me: String) -> some View {
        switch mode {
        case .cards:
            CardsView(sections: sections, namespace: namespace, select: open)
        case .list:
            ListView(sections: sections, namespace: namespace, select: open)
        case .board:
            if grouping == .vibe {
                ClusterBoardView(drops: drops, namespace: namespace, filter: filter, me: me, select: open)
            } else {
                PaperBoardRoot(sections: sections, namespace: namespace, select: open)
            }
        case .night:
            EmptyView()
        }
    }

    @ViewBuilder
    private func boardMenu(_ known: [RemoteBoard], current: String) -> some View {
        ForEach(known) { choice in
            Button {
                show(choice.boardId)
            } label: {
                if choice.boardId == current {
                    Label(choice.name, systemImage: "checkmark")
                } else {
                    Text(choice.name)
                }
            }
        }
        Divider()
        Button("start a shared board", systemImage: "person.2") { boards.entry = .create }
        Button("join with a code", systemImage: "number") { boards.entry = .join(code: nil) }
    }

    private var knownBoards: [RemoteBoard] {
        var known = boards.boards
        #if DEBUG
        for seeded in SeedBoard.boards where !known.contains(where: { $0.boardId == seeded.boardId }) {
            if drops.contains(where: { $0.boardId == seeded.boardId }) { known.append(seeded) }
        }
        #endif
        return known
    }

    private func open(_ drop: Drop) {
        path.append(drop)
    }

    private func show(_ boardId: String) {
        path.removeAll()
        filter = .everyone
        boards.show(boardId)
    }
}
