import SwiftUI

struct BoardMood: Identifiable, Equatable {
    let id: String
    let label: String
    let drops: [Drop]
    let fresh: Int
    let lastActive: Date

    static func == (a: BoardMood, b: BoardMood) -> Bool {
        a.id == b.id && a.label == b.label && a.drops.map(\.id) == b.drops.map(\.id) && a.fresh == b.fresh
    }

    static let freshWindow: TimeInterval = 3 * 3600
    static let quietAfter: TimeInterval = 14 * 86400

    static func build(_ drops: [Drop], me: String, now: Date) -> (active: [BoardMood], quiet: [BoardMood]) {
        let live = drops.filter { $0.boardZone(now: now) != .done && !$0.isArriving }
        let byId = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var moods: [BoardMood] = []
        for group in ClusterSnapshot(drops: live).groups where group.shelf != .done {
            let members = group.members.compactMap { byId[$0] }.sorted { $0.createdAt > $1.createdAt }
            guard let newest = members.first else { continue }
            let key: String = switch group.shelf {
            case .pinned: "pinned"
            case .loose: "loose"
            default: newest.clusterId ?? group.id
            }
            moods.append(BoardMood(
                id: key,
                label: group.shelf == .loose ? "not sorted yet" : group.label,
                drops: members,
                fresh: members.filter { $0.authorId != me && now.timeIntervalSince($0.createdAt) < freshWindow }.count,
                lastActive: newest.createdAt
            ))
        }
        moods.sort { a, b in
            if (a.id == "pinned") != (b.id == "pinned") { return a.id == "pinned" }
            return a.lastActive > b.lastActive
        }
        let active = moods.filter { $0.id == "pinned" || now.timeIntervalSince($0.lastActive) < quietAfter }
        let quiet = moods.filter { !active.contains($0) }
        return (active, quiet)
    }

    func members(of drops: [Drop], now: Date) -> [Drop] {
        drops.filter { drop in
            guard drop.boardZone(now: now) != .done else { return false }
            switch id {
            case "pinned": return drop.isPinned
            case "loose": return !drop.isPinned && drop.clusterId == nil
            default: return !drop.isPinned && drop.clusterId == id
            }
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}

struct MoodHome: View {
    let drops: [Drop]
    let me: String
    let namespace: Namespace.ID
    let openMood: (BoardMood) -> Void

    @Environment(BoardClock.self) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsQuiet = false
    @State private var order: [String] = []

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = max(clock.now, context.date)
            let moods = BoardMood.build(drops, me: me, now: now)
            let tiles = Self.arrange(moods.active, by: order)
            let reading = drops.filter(\.isArriving)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(reading.last.map { "reading what \($0.authorLabel) just shared." } ?? Self.line(moods.active, now: now))
                        .font(.subheadline)
                        .foregroundStyle(reading.isEmpty ? NightStyle.secondary : Color.white)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.smooth(duration: 0.3), value: reading.count)
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("moodLine")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(tiles) { mood in
                            Button { openMood(mood) } label: {
                                MoodTile(mood: mood, now: now)
                            }
                            .buttonStyle(NightPressStyle())
                            .matchedTransitionSource(id: mood.id, in: namespace) { $0.clipShape(NightStyle.card) }
                            .accessibilityIdentifier("moodTile")
                        }
                    }
                    .padding(.horizontal, 16)
                    if !moods.quiet.isEmpty {
                        quiet(moods.quiet, now: now)
                    }
                }
                .padding(.bottom, 40)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : ClusterMotion.drift, value: tiles.map(\.id))
            }
            .scrollIndicators(.hidden)
            .onAppear { order = moods.active.map(\.id) }
            .onChange(of: moods.active.map(\.id)) { _, ids in
                let fresh = ids.filter { !order.contains($0) }
                guard !fresh.isEmpty else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : ClusterMotion.drift) {
                    order = (order.first == "pinned" ? ["pinned"] : []) + fresh + order.filter { $0 != "pinned" }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("moodHome")
    }

    private func quiet(_ moods: [BoardMood], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(LayoutMotion.settle(reduceMotion)) { showsQuiet.toggle() }
            } label: {
                Label("\(moods.count) quiet for a while", systemImage: showsQuiet ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NightStyle.secondary)
            }
            .buttonStyle(.plain)
            if showsQuiet {
                ForEach(moods) { mood in
                    Button { openMood(mood) } label: {
                        HStack(spacing: 10) {
                            LayoutBadge(drop: mood.drops[0], size: 36, showsKind: false)
                            Text(mood.label).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(mood.drops.count)").font(.subheadline).foregroundStyle(NightStyle.tertiary).monospacedDigit()
                        }
                    }
                    .buttonStyle(NightPressStyle())
                    .matchedTransitionSource(id: mood.id, in: namespace)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    static func arrange(_ moods: [BoardMood], by order: [String]) -> [BoardMood] {
        guard !order.isEmpty else { return moods }
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return moods.sorted { (rank[$0.id] ?? -1, $0.lastActive) < (rank[$1.id] ?? -1, $1.lastActive) }
    }

    static func line(_ moods: [BoardMood], now: Date) -> String {
        let things = moods.reduce(0) { $0 + $1.drops.count }
        let vibes = moods.filter { $0.id != "pinned" && $0.id != "loose" }.count
        let latest = moods.flatMap(\.drops).max { $0.createdAt < $1.createdAt }
        guard let latest, now.timeIntervalSince(latest.createdAt) < 3600 else {
            return "\(things) things in \(vibes == 1 ? "one mood" : "\(vibes) moods")."
        }
        let when = now.timeIntervalSince(latest.createdAt) < 60 ? "just now" : latest.createdAt.formatted(.relative(presentation: .named)).lowercased()
        return "\(latest.authorLabel) added \(ConstellationView.article(latest.kind)) \(when)."
    }
}

private struct MoodTile: View {
    let mood: BoardMood
    let now: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private func fanned(_ drop: Drop, index: Int) -> some View {
        let tilt: Double = index == 0 ? 0 : (index == 1 ? -4 : 4)
        let size: CGFloat = index == 0 ? 64 : 54
        let x = CGFloat(index) * 40
        let y: CGFloat = index == 0 ? 0 : 6
        let transition: AnyTransition = reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity)
        return LayoutBadge(drop: drop, size: size, showsKind: index == 0)
            .rotationEffect(.degrees(tilt))
            .offset(x: x, y: y)
            .zIndex(Double(3 - index))
            .transition(transition)
    }

    var body: some View {
        let latest = mood.drops.first
        let glow = latest?.personColor ?? .white
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .leading) {
                ForEach(Array(mood.drops.prefix(3).enumerated()), id: \.element.id) { index, drop in
                    fanned(drop, index: index)
                }
            }
            .frame(height: 72, alignment: .leading)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.2), value: mood.drops.prefix(3).map(\.id))
            Spacer(minLength: 0)
            Text(mood.label)
                .font(.headline.weight(.bold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("\(mood.drops.count) \(mood.drops.count == 1 ? "thing" : "things")")
                    .font(.footnote)
                    .foregroundStyle(NightStyle.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if mood.fresh > 0 {
                    Text("\(mood.fresh) new")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.14), in: .capsule)
                        .contentTransition(.numericText())
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(NightStyle.surface)
        .clipShape(NightStyle.card)
        .overlay {
            NightStyle.card.strokeBorder(pulse ? glow.opacity(0.8) : NightStyle.hairline, lineWidth: 1)
        }
        .scaleEffect(pulse && !reduceMotion ? 1.02 : 1)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: mood.drops.count)
        .onChange(of: mood.drops.count) { old, new in
            guard new > old else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2)) { pulse = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.smooth(duration: 0.8)) { pulse = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mood.label), \(mood.drops.count) things\(mood.fresh > 0 ? ", \(mood.fresh) new" : "")")
    }
}

struct MoodScreen: View {
    let mood: BoardMood
    let drops: [Drop]
    let palette: NightPalette
    let namespace: Namespace.ID
    let open: (Drop) -> Void

    @Environment(BoardClock.self) private var clock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    static var firstCap: Int {
        #if DEBUG
        let asked = UserDefaults.standard.integer(forKey: "LayoutMoodCap")
        if asked > 0 { return asked }
        #endif
        return 7
    }

    var body: some View {
        let members = mood.members(of: drops, now: clock.now)
        let cap = Self.firstCap
        let start = min(page * cap, max(members.count - 1, 0))
        let shown = Array(members.dropFirst(start).prefix(cap))
        let earlier = members.count - start - shown.count
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(mood.label)
                    .font(NightStyle.pageTitle)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if earlier > 0 {
                    Button("\(earlier) earlier", systemImage: "square.stack") {
                        withAnimation(LayoutMotion.settle(reduceMotion)) { page += 1 }
                    }
                    .buttonStyle(.glass)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("earlierStack")
                } else if page > 0 {
                    Button("newest", systemImage: "arrow.uturn.up") {
                        withAnimation(LayoutMotion.settle(reduceMotion)) { page = 0 }
                    }
                    .buttonStyle(.glass)
                    .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)
            Text("\(members.count) \(members.count == 1 ? "thing" : "things")")
                .font(.subheadline)
                .foregroundStyle(NightStyle.secondary)
                .contentTransition(.numericText())
                .padding(.horizontal, 20)
            ConstellationView(drops: shown, namespace: namespace, open: open) { dismiss() }
        }
        .background { NightBackdrop(palette: palette) }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("moodScreen")
    }
}
