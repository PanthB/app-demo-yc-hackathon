import SwiftData
import SwiftUI

struct NightBoardView: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var allDrops: [Drop]
    @Environment(BoardClock.self) private var clock
    @State private var chosenBoard: String?
    @State private var filter: DropFilter = .everyone
    @State private var path: [UUID] = []
    @State private var showsStreaks = false
    @State private var moment = 0
    @State private var holdsDemoStreak = Self.asksForStreakDemo
    @Namespace private var namespace

    private struct StreakMark: Equatable {
        let board: String
        let days: Int
    }

    var body: some View {
        let personal = DeviceIdentity.boardId
        let choices = Self.boards(in: allDrops, personal: personal)
        let current = chosenBoard ?? Self.opening(choices, personal: personal)
        let drops = allDrops.filter { Self.board(of: $0, personal: personal) == current }
        let members = Self.members(of: drops)
        let isShared = members.count > 1
        let palette = NightPalette.forBoard(current, personal: current == personal)
        let name = choices.first { $0.id == current }?.name ?? "my board"
        let me = DeviceIdentity.personId
        let streaks = BoardStreaks(drops: drops, me: me, now: clock.now)
        let mine = holdsDemoStreak ? DailyStreak(days: max(streaks.mine.days - 1, 0), droppedToday: false) : streaks.mine

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NightHeader(
                        boardName: name,
                        boards: choices,
                        currentBoardId: current,
                        line: Self.line(streaks, isShared: isShared),
                        isShared: isShared,
                        filter: $filter
                    ) { id in
                        withAnimation(.smooth(duration: 0.4)) {
                            chosenBoard = id
                            filter = .everyone
                        }
                    }
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
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background { NightBackdrop(palette: palette) }
            .overlay(alignment: .top) {
                LinearGradient(stops: [.init(color: NightStyle.ink.opacity(0.95), location: 0), .init(color: NightStyle.ink.opacity(0.75), location: 0.55), .init(color: NightStyle.ink.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
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
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NightViewMenu()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let drop = allDrops.first(where: { $0.id == id }) {
                    NightDetail(drop: drop, palette: palette)
                        .navigationTransition(.zoom(sourceID: id, in: namespace))
                }
            }
        }
        .sheet(isPresented: $showsStreaks) {
            NightStreakSheet(boardName: name, streaks: streaks, members: members, me: me, isShared: isShared)
        }
        .onChange(of: StreakMark(board: current, days: mine.days)) { before, after in
            if before.board == after.board, after.days > before.days { moment += 1 }
        }
        .task {
            guard holdsDemoStreak else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.snappy) { holdsDemoStreak = false }
        }
        .tint(palette.ember)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("nightBoard")
    }

    static func board(of drop: Drop, personal: String) -> String {
        drop.boardId.isEmpty ? personal : drop.boardId
    }

    static func boards(in drops: [Drop], personal: String) -> [NightBoardChoice] {
        var seen: Set<String> = [personal]
        var choices = [NightBoardChoice(id: personal, name: "my board")]
        for drop in drops {
            let id = board(of: drop, personal: personal)
            guard seen.insert(id).inserted else { continue }
            choices.append(NightBoardChoice(id: id, name: id.replacingOccurrences(of: "-", with: " ").lowercased()))
        }
        return choices
    }

    static func opening(_ choices: [NightBoardChoice], personal: String) -> String {
        #if DEBUG
        if let asked = UserDefaults.standard.string(forKey: "NightBoard"), choices.contains(where: { $0.id == asked }) {
            return asked
        }
        #endif
        return personal
    }

    static func members(of drops: [Drop]) -> [NightMember] {
        var seen: Set<String> = []
        return drops.sorted { $0.createdAt < $1.createdAt }.compactMap { drop in
            guard seen.insert(drop.authorId).inserted else { return nil }
            return NightMember(id: drop.authorId, name: drop.authorLabel, color: drop.authorColor)
        }
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
