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
    @State private var tab: NightTab = .board
    @State private var web: BoardWebStop?
    @State private var moment = 0
    @State private var holdsDemoStreak = Self.asksForStreakDemo
    @State private var landing: UUID?
    @State private var settling: UUID?
    @State private var held: Set<UUID> = []
    @Environment(\.scenePhase) private var scenePhase
    @State private var queueTick = Date.now
    @State private var flight = NightFlightModel()
    @State private var calibration = SuggestionsModel()
    @State private var toast: NightToastItem?
    @State private var unreadArrival: UUID?
    @State private var sectionInView: String?
    @State private var isScrolled = false
    @State private var landed = 0
    @State private var grouped = 0
    @Namespace private var moves
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    private struct Arrivals: Equatable {
        let board: String
        let ids: [UUID]
    }

    private struct QueueMark: Equatable {
        let board: String
        let ids: [UUID]
    }

    private static let queueTime: TimeInterval = 60

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

        let now = max(queueTick, Date.now)
        let reading = drops.filter { $0.isArriving && now.timeIntervalSince($0.createdAt) < Self.queueTime }
        let readingIds = Set(reading.map(\.id)).union(held)
        let queued = drops.filter { $0.authorId == me && readingIds.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
        let sections = DropSection.build(drops.filter { !readingIds.contains($0.id) }, grouping: isShared ? .vibe : .when, filter: filter, me: me, now: clock.now)
        let calibrating = Set(calibration.groups?.filter(\.searching).map(\.clusterId) ?? [])

        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if tab == .board {
                    header(name: name, choices: choices, current: current, streaks: streaks, isShared: isShared)
                    NightFeed(
                        sections: sections,
                        namespace: namespace,
                        moves: moves,
                        select: { drop in path.append(drop.id) },
                        openGroup: { web = BoardWebStop(focus: $0) },
                        landing: landing,
                        calibrating: calibrating,
                        report: { flight.target = $0 }
                    )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 2 } action: { _, scrolled in
                isScrolled = scrolled
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { NightBackdrop(palette: palette, isLiving: false) }
            .overlay {
                if tab == .suggestions {
                    VStack(alignment: .leading, spacing: 0) {
                        header(name: name, choices: choices, current: current, streaks: streaks, isShared: isShared)
                        SuggestionsFeed(boardId: current, embedded: true)
                            .tint(palette.ember)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.opacity)
                }
            }
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
                    SettingsButton()
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if let toast {
                        NightToast(text: toast.text) {
                            reveal(toast.id, in: sections, proxy: proxy)
                            withAnimation(reduceMotion ? nil : .smooth) { self.toast = nil }
                        }
                        .padding(.horizontal, NightStyle.margin)
                        .transition(.opacity.combined(with: .offset(y: 16)))
                    }
                    NightQueue(drops: queued, flight: flight)
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
            }
            .navigationDestination(item: $web) { stop in
                BoardWeb(boardId: boards.currentBoardId, focus: stop.focus)
                    .navigationTransition(.zoom(sourceID: stop.id, in: namespace))
            }
            .navigationDestination(for: UUID.self) { id in
                if let drop = allDrops.first(where: { $0.id == id }) {
                    NightDetail(drop: drop, palette: palette)
                        .navigationTransition(.zoom(sourceID: id, in: namespace))
                }
            }
            .overlay { NightFlightLayer(flight: flight) }
            .safeAreaInset(edge: .top, spacing: 0) {
                let jumps = sections.filter { $0.style != .done }
                if tab == .board, jumps.count > 1 {
                    NightJumpRow(sections: jumps, current: sectionInView ?? jumps.first?.id) { id in
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) { proxy.scrollTo(id, anchor: .top) }
                    }
                    .background {
                        VStack(spacing: 0) {
                            NightStyle.ink
                            LinearGradient(colors: [NightStyle.ink, NightStyle.ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 16)
                                .padding(.bottom, -16)
                        }
                        .ignoresSafeArea(edges: .top)
                        .opacity(isScrolled ? 1 : 0)
                        .animation(.easeOut(duration: 0.18), value: isScrolled)
                        .allowsHitTesting(false)
                    }
                }
            }
            .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.2) { ids in
                sectionInView = ids.first
            }
            .onAppear { replay(drops, me: me) }
            .onChange(of: current) { replay(drops, me: me) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { replay(drops, me: me) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NightReplay.asked)) { _ in
                tab = .board
                replay(drops, me: me)
            }
            .onChange(of: Arrivals(board: current, ids: drops.map(\.id))) { before, after in
                guard before.board == after.board else { return }
                let added = Set(after.ids).subtracting(before.ids)
                guard let drop = drops.first(where: { added.contains($0.id) && $0.createdAt > .now.addingTimeInterval(-120) }) else { return }
                if drop.authorId == me {
                    hold([drop.id])
                } else if drop.isArriving {
                    unreadArrival = drop.id
                } else {
                    withAnimation(reduceMotion ? nil : .snappy) { toast = NightToastItem(id: drop.id, text: ShellToast.words(for: drop)) }
                }
            }
            .onChange(of: unreadArrival.flatMap { id in drops.first { $0.id == id }?.isArriving }) { _, arriving in
                guard arriving == false, let id = unreadArrival, let drop = drops.first(where: { $0.id == id }) else { return }
                unreadArrival = nil
                withAnimation(reduceMotion ? nil : .snappy) { toast = NightToastItem(id: drop.id, text: ShellToast.words(for: drop)) }
            }
            .onChange(of: QueueMark(board: current, ids: queued.map(\.id))) { before, after in
                guard before.board == after.board else { return }
                if !Set(after.ids).subtracting(before.ids).isEmpty { landed += 1 }
                let left = Set(before.ids).subtracting(after.ids)
                guard let drop = drops.first(where: { left.contains($0.id) && Self.section(of: $0.id, in: sections) != nil }) else { return }
                land(drop, sections: sections, proxy: proxy, me: me)
            }
            .onChange(of: settling.flatMap { Self.section(of: $0, in: sections) }) { _, after in
                guard let id = settling, let after, after.hasPrefix("cluster-"), let section = sections.first(where: { $0.id == after }) else { return }
                settling = nil
                reveal(id, in: sections, proxy: proxy)
                withAnimation(reduceMotion ? nil : .snappy) { toast = NightToastItem(id: id, text: Self.settledWords(section, me: me)) }
            }
            .task(id: reading.map(\.id)) {
                guard let oldest = reading.map(\.createdAt).min() else { return }
                let left = Self.queueTime - Date.now.timeIntervalSince(oldest)
                try? await Task.sleep(for: .seconds(max(left, 0.5)))
                guard !Task.isCancelled else { return }
                queueTick = .now
            }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: landed)
        .sensoryFeedback(.success, trigger: grouped)
        .task(id: settling) {
            guard settling != nil else { return }
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            settling = nil
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .smooth) { toast = nil }
        }
        .task(id: unreadArrival) {
            guard let id = unreadArrival else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, unreadArrival == id, let drop = allDrops.first(where: { $0.id == id }) else { return }
            unreadArrival = nil
            withAnimation(reduceMotion ? nil : .snappy) { toast = NightToastItem(id: id, text: "\(CardWords.clean(drop.authorName) ?? "someone") dropped something.") }
        }
        .task(id: current) {
            calibration.follow(boardId: current, personId: me)
        }
        .onDisappear { calibration.stop() }
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

    private func header(name: String, choices: [NightBoardChoice], current: String, streaks: BoardStreaks, isShared: Bool) -> some View {
        NightHeader(
            boardName: name,
            boards: choices,
            currentBoardId: current,
            line: Self.line(streaks, isShared: isShared),
            isShared: isShared,
            filter: $filter,
            tab: $tab,
            showBoard: { id in
                withAnimation(.smooth(duration: 0.4)) {
                    boards.show(id)
                    filter = .everyone
                }
            },
            startBoard: { boards.entry = .create },
            joinBoard: { boards.entry = .join(code: nil) },
            seeFull: { web = BoardWebStop(focus: nil) }
        )
        .matchedTransitionSource(id: "web-all", in: namespace)
    }

    private func replay(_ drops: [Drop], me: String) {
        let asked = NightReplay.pending
        if let asked, drops.contains(where: { $0.id == asked }) { NightReplay.pending = nil }
        let since = Date.now.addingTimeInterval(-120)
        hold(drops.filter { $0.authorId == me && ($0.createdAt > since || $0.id == asked) }.sorted { $0.createdAt < $1.createdAt }.map(\.id))
    }

    private func hold(_ ids: [UUID]) {
        let fresh = NightReplay.unplayed(ids.filter { !held.contains($0) })
        guard !fresh.isEmpty else { return }
        NightReplay.played(fresh)
        held.formUnion(fresh)
        for (index, id) in fresh.enumerated() {
            Task {
                try? await Task.sleep(for: .milliseconds(650 + index * 1400))
                held.remove(id)
            }
        }
    }

    private func land(_ drop: Drop, sections: [DropSection], proxy: ScrollViewProxy, me: String) {
        let id = drop.id
        let banner = Self.section(of: id, in: sections)
            .flatMap { sectionId in sections.first { $0.id == sectionId } }
            .flatMap { $0.id.hasPrefix("cluster-") ? Self.settledWords($0, me: me) : nil }
        let finish: @MainActor () -> Void = {
            grouped += 1
            if let banner {
                withAnimation(reduceMotion ? nil : .snappy) { toast = NightToastItem(id: id, text: banner) }
            } else {
                settling = id
            }
        }
        guard tab == .board else {
            finish()
            return
        }
        guard !reduceMotion, flight.drop == nil, let bubble = flight.bubbleFrames[id] else {
            landing = id
            reveal(id, in: sections, proxy: proxy)
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeInOut(duration: 0.3)) { landing = nil }
                finish()
            }
            return
        }
        flight.start(drop, from: CGPoint(x: bubble.midX, y: bubble.midY))
        landing = id
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.snappy(duration: 0.2)) { flight.lifted = true }
            reveal(id, in: sections, proxy: proxy)
            try? await Task.sleep(for: .milliseconds(780))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                landing = nil
                flight.popped = true
            }
            finish()
            try? await Task.sleep(for: .milliseconds(380))
            flight.end()
        }
    }

    private func reveal(_ id: UUID, in sections: [DropSection], proxy: ScrollViewProxy) {
        guard let section = Self.section(of: id, in: sections) else { return }
        let motion: Animation? = reduceMotion ? nil : .smooth(duration: 0.5)
        withAnimation(motion) { proxy.scrollTo(section, anchor: .top) }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(motion) { proxy.scrollTo(id, anchor: .center) }
        }
    }

    static func settledWords(_ section: DropSection, me: String) -> String {
        let others = Dictionary(grouping: section.drops.filter { $0.authorId != me && !$0.authorId.isEmpty }, by: \.authorId)
            .sorted { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }
            .compactMap { $0.value.first.map(\.authorLabel) }
            .prefix(3)
        let names = Array(others)
        guard let last = names.last else { return "in \(section.title) · a new vibe for the crew." }
        let joined = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
        return "in \(section.title) · closest to \(joined)'s vibes."
    }

    static func section(of id: UUID, in sections: [DropSection]) -> String? {
        sections.first { $0.drops.contains { $0.id == id } }?.id
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
