import Foundation

enum DropFilter: String, CaseIterable, Sendable {
    case everyone, mine
}

struct DropSection: Identifiable {
    enum Style {
        case pinned, zone, done
    }

    let id: String
    let title: String
    let style: Style
    let drops: [Drop]

    static func build(
        _ drops: [Drop],
        filter: DropFilter,
        me: String,
        now: Date,
        calendar: Calendar = .current
    ) -> [DropSection] {
        let shown = filter == .mine ? drops.filter { $0.authorId == me } : drops
        let atTop = shown.filter { $0.isPinned && $0.zone != .done }
        let board = BoardContents(shown.filter { !($0.isPinned && $0.zone != .done) }, now: now, calendar: calendar)

        var sections = [
            DropSection(
                id: "pinned",
                title: "pinned",
                style: .pinned,
                drops: atTop.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
            )
        ]
        for zone in Zone.allCases {
            sections.append(DropSection(
                id: zone.rawValue,
                title: zone.displayName,
                style: zone == .done ? .done : .zone,
                drops: zone == .now ? board.arriving + board.drops(in: .now) : board.drops(in: zone)
            ))
        }
        return sections.filter { !$0.drops.isEmpty }
    }
}
