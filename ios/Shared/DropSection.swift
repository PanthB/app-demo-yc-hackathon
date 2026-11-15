import Foundation

enum DropFilter: String, CaseIterable, Sendable {
    case everyone, mine
}

enum DropGrouping: String, CaseIterable, Sendable {
    case when, vibe

    var menuName: String {
        switch self {
        case .when: "by when"
        case .vibe: "by mood"
        }
    }
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
        grouping: DropGrouping = .when,
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
        switch grouping {
        case .when:
            for zone in Zone.allCases where zone != .done {
                sections.append(DropSection(
                    id: zone.rawValue,
                    title: zone.displayName,
                    style: .zone,
                    drops: zone == .now ? board.arriving + board.drops(in: .now) : board.drops(in: zone)
                ))
            }
        case .vibe:
            var clusters: [String: [Drop]] = [:]
            var loose: [Drop] = board.arriving
            for zone in Zone.allCases where zone != .done {
                for drop in board.drops(in: zone) {
                    if let clusterId = drop.clusterId {
                        clusters[clusterId, default: []].append(drop)
                    } else {
                        loose.append(drop)
                    }
                }
            }
            let ordered = clusters
                .map { id, members in (id: id, members: members.sorted { $0.createdAt > $1.createdAt }) }
                .sorted { a, b in
                    if a.members.count != b.members.count { return a.members.count > b.members.count }
                    let aNewest = a.members.first?.createdAt ?? .distantPast
                    let bNewest = b.members.first?.createdAt ?? .distantPast
                    return aNewest != bNewest ? aNewest > bNewest : a.id < b.id
                }
            for cluster in ordered {
                sections.append(DropSection(
                    id: "cluster-\(cluster.id)",
                    title: cluster.members.first?.clusterLabel ?? "these go together",
                    style: .zone,
                    drops: cluster.members
                ))
            }
            sections.append(DropSection(
                id: "loose",
                title: "everything else",
                style: .zone,
                drops: loose.sorted { $0.createdAt > $1.createdAt }
            ))
        }
        sections.append(DropSection(id: Zone.done.rawValue, title: Zone.done.displayName, style: .done, drops: board.drops(in: .done)))
        return sections.filter { !$0.drops.isEmpty }
    }
}
