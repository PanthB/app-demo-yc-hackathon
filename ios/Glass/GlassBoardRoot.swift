import SwiftData
import SwiftUI

struct GlassSection: Identifiable {
    enum Style {
        case pinned, zone, done
    }

    let id: String
    let title: String
    let style: Style
    let drops: [Drop]

    static func build(_ drops: [Drop], now: Date) -> [GlassSection] {
        let pinned = drops.filter { $0.pinned && $0.zone != .done }.sorted { $0.sortDate < $1.sortDate }
        let board = BoardContents(drops.filter { !$0.pinned || $0.zone == .done }, now: now)
        var sections = [GlassSection(id: "pinned", title: "pinned", style: .pinned, drops: pinned)]
        for zone in [Zone.now, .tonight, .thisWeekend, .someday, .vibes] {
            let arriving = zone == .now ? board.arriving : []
            sections.append(GlassSection(id: zone.rawValue, title: zone.displayName, style: .zone, drops: arriving + board.drops(in: zone)))
        }
        sections.append(GlassSection(id: "done", title: Zone.done.displayName, style: .done, drops: board.drops(in: .done)))
        return sections.filter { !$0.drops.isEmpty }
    }
}

struct GlassBoardRoot: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @Environment(BoardClock.self) private var clock
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            CardsView(sections: GlassSection.build(drops, now: clock.now), namespace: namespace) { _ in }
                .navigationTitle("my board")
        }
        .tint(Color(red: 1.0, green: 0.42, blue: 0.29))
        #if DEBUG
        .task(id: drops.count) {
            guard UserDefaults.standard.bool(forKey: "GlassDebugPins"), !drops.contains(where: \.pinned) else { return }
            let board = BoardContents(drops, now: clock.now)
            for drop in [board.drops(in: .tonight).first, board.drops(in: .vibes).last, board.drops(in: .thisWeekend).first].compactMap({ $0 }) {
                drop.pinned = true
            }
        }
        #endif
    }
}
