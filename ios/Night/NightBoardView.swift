import SwiftData
import SwiftUI

struct NightBoardView: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var allDrops: [Drop]
    @Environment(BoardClock.self) private var clock
    @Environment(BoardsStore.self) private var boards
    @Environment(BoardSync.self) private var sync
    @Environment(\.dropActions) private var baseActions
    @State private var filter: DropFilter = .everyone
    @State private var path: [UUID] = []
    @State private var showsStreaks = false
    @State private var showsSuggestions = false
    @State private var moment = 0
    @State private var holdsDemoStreak = Self.asksForStreakDemo
    @Namespace private var namespace

    private struct StreakMark: Equatable {
        let board: String
        let days: Int
    }

    var body: some View {
        let personal = BoardKeys.personalBoard
        let current = boards.currentBoardId
        let choices = Self.choices(boards.boards, drops: allDrops, personal: personal)
        let drops = allDrops.filter { Self.board(of: $0, personal: personal) == current }
        let members = Self.members(boards.currentBoard?.members ?? [], drops: drops)
        let isShared = boards.currentBoard?.shared ?? (members.count > 1)
        let palette = NightPalette.forBoard(current, personal: current == personal)
        let name = boards.currentBoard?.name ?? choices.first { $0.id == current }?.name ?? boards.currentBoardName
        let me = boards.personId
        let streaks = shownStreaks(drops, me: me)
        let mine = streaks.mine

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NightHeader(
                        boardName: name,
                        boards: choices,
                        currentBoardId: current,
                        line: Self.line(streaks, isShared: isShared),
                        isShared: isShared,
                        filter: $filter,
                        showBoard: { id in
                            withAnimation(.smooth(duration: 0.4)) {
                                boards.show(id)
                                filter = .everyone
                            }
                        },
                        startBoard: { boards.entry = .create },
                        joinBoard: { boards.entry = .join(code: nil) },
                        openSuggestions: { showsSuggestions = true }
                    )
                    NightFeed(
                        sections: DropSection.build(drops, grouping: isShared ? .vibe : .when, filter: filter, me: me, now: clock.now),
                        namespace: namespace
                    ) { drop in
                        path.append(drop.id)
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background { NightBackdrop(palette: palette, isLiving: false) }
            .overlay(alignment: .top) {
                LinearGradient(stops: [.init(color: NightStyle.ink.opacity(0.97), location: 0), .init(color: NightStyle.ink.opacity(0.94), location: 0.62), .init(color: NightStyle.ink.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 130)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NightStreakChip(streak: mine, moment: moment) { showsStreaks = true }
                }
                if isShared {
                    ToolbarItem(placement: .topBarTrailing) {
                        NightMembers(members: members, streaks: streaks.members) { showsStreaks = true }
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NightViewMenu()
                }
            }
            .overlay(alignment: .bottom) {
                NightAddButton()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.bottom, 4)
                    .background {
                        LinearGradient(colors: [NightStyle.ink.opacity(0), NightStyle.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea(edges: .bottom)
                            .allowsHitTesting(false)
                    }
            }
            .navigationDestination(for: UUID.self) { id in
                if let drop = allDrops.first(where: { $0.id == id }) {
                    NightDetail(drop: drop, palette: palette)
                        .navigationTransition(.zoom(sourceID: id, in: namespace))
                }
            }
        }
        .sheet(isPresented: $showsSuggestions) {
            NavigationStack {
                SuggestionsFeed(boardId: current)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("done") { showsSuggestions = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showsStreaks) {
            NightStreakSheet(boardName: name, streaks: streaks, members: members, me: me, isShared: isShared, invite: boards.currentBoard?.inviteLink, inviteCode: boards.currentBoard?.inviteCode)
        }
        .onChange(of: StreakMark(board: current, days: mine.days)) { before, after in
            if before.board == after.board, after.days > before.days { moment += 1 }
        }
        .environment(\.dropActions, DropActions(
            pin: { sync.setPinned($0, $1) },
            move: { sync.move($0, to: $1) },
            done: { sync.markDone($0) },
            undo: { sync.undoMove($0) },
            open: baseActions.open
        ))
        #if DEBUG
        .task {
            if let asked = UserDefaults.standard.string(forKey: "NightBoard"), !asked.isEmpty {
                boards.show(asked)
            }
        }
        #endif
        .task {
            guard holdsDemoStreak else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.snappy) { holdsDemoStreak = false }
        }
        .tint(palette.ember)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("nightBoard")
    }

    static func board(of drop: Drop, personal: String) -> String {
        drop.boardId.isEmpty ? personal : drop.boardId
    }

    static func choices(_ remote: [RemoteBoard], drops: [Drop], personal: String) -> [NightBoardChoice] {
        var seen: Set<String> = []
        var choices: [NightBoardChoice] = []
        for board in remote where seen.insert(board.boardId).inserted {
            choices.append(NightBoardChoice(id: board.boardId, name: board.boardId == personal ? "my board" : board.name))
        }
        if seen.insert(personal).inserted {
            choices.insert(NightBoardChoice(id: personal, name: "my board"), at: 0)
        }
        for drop in drops {
            let id = board(of: drop, personal: personal)
            guard seen.insert(id).inserted else { continue }
            choices.append(NightBoardChoice(id: id, name: id.replacingOccurrences(of: "-", with: " ").lowercased()))
        }
        return choices
    }

    static func members(_ remote: [RemoteMember], drops: [Drop]) -> [NightMember] {
        var seen = Set(remote.map(\.personId))
        return remote.map { NightMember(id: $0.personId, name: $0.name, color: $0.color) } + drops.sorted { $0.createdAt < $1.createdAt }.compactMap { drop in
            guard seen.insert(drop.authorId).inserted else { return nil }
            return NightMember(id: drop.authorId, name: drop.authorLabel, color: drop.authorColor)
        }
    }

    private func shownStreaks(_ drops: [Drop], me: String) -> BoardStreaks {
        var streaks = BoardStreaks(drops: drops, me: me, now: BoardStreaks.now(clock: clock.now, drops: drops.map(\.createdAt)))
        if holdsDemoStreak {
            streaks.mine = DailyStreak(days: max(streaks.mine.days - 1, 0), droppedToday: false)
        }
        return streaks
    }

    static func line(_ streaks: BoardStreaks, isShared: Bool) -> String {
        guard isShared, streaks.mine.isAlive, streaks.crew.days > 1 else { return streaks.headline }
        return "\(streaks.headline) the crew is on a \(streaks.crew.days) day run."
    }

    private static var asksForStreakDemo: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "NightStreakDemo")
        #else
        false
        #endif
    }
}
