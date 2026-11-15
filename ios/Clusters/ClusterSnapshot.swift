import Foundation
import SwiftUI

struct ClusterSnapshot: Equatable {
    enum Shelf: Equatable {
        case pinned, cluster, loose, done
    }

    struct Group: Identifiable, Equatable {
        let id: String
        let shelf: Shelf
        let label: String
        let members: [UUID]
    }

    struct Pair: Identifiable, Equatable {
        let id: String
        let first: UUID
        let second: UUID
        let reason: String
    }

    private(set) var groups: [Group] = []
    private(set) var pairs: [Pair] = []
    private var home: [UUID: String] = [:]
    private var visual: [String: String] = [:]

    init(drops: [Drop], following previous: ClusterSnapshot? = nil) {
        let byAge: (Drop, Drop) -> Bool = { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        var pinned: [Drop] = []
        var loose: [Drop] = []
        var done: [Drop] = []
        var clusters: [String: [Drop]] = [:]
        for drop in drops {
            if drop.zone == .done {
                done.append(drop)
            } else if drop.isPinned {
                pinned.append(drop)
            } else if let clusterId = drop.clusterId {
                clusters[clusterId, default: []].append(drop)
            } else {
                loose.append(drop)
            }
        }

        let clusterOrder = clusters.keys.sorted {
            let first = clusters[$0]?.map(\.createdAt).min() ?? .distantFuture
            let second = clusters[$1]?.map(\.createdAt).min() ?? .distantFuture
            return (first, $0) < (second, $1)
        }
        let members = clusters.mapValues { $0.sorted(by: byAge).map(\.id) }
        visual = Self.stableIds(for: clusterOrder, members: members, previous: previous)

        var pairOrder: [UUID] = []
        var clusterOf: [UUID: String] = [:]
        for clusterId in clusterOrder {
            for id in members[clusterId] ?? [] {
                pairOrder.append(id)
                clusterOf[id] = clusterId
            }
        }
        let neighbors = Dictionary(drops.map { ($0.id, $0.neighbors) }, uniquingKeysWith: { first, _ in first })
        pairs = Self.pairs(order: pairOrder, cluster: clusterOf, neighbors: neighbors)

        if !pinned.isEmpty {
            let sorted = pinned.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
            groups.append(Group(id: "pinned", shelf: .pinned, label: "pinned", members: sorted.map(\.id)))
        }
        for clusterId in clusterOrder {
            let drops = clusters[clusterId]?.sorted(by: byAge) ?? []
            let label = drops.reversed().lazy.compactMap { CardWords.clean($0.clusterLabel) }.first ?? "together"
            groups.append(Group(
                id: visual[clusterId] ?? "cluster-\(clusterId)",
                shelf: .cluster,
                label: label,
                members: Self.arrange(drops.map(\.id), pairs: pairs)
            ))
        }
        if !loose.isEmpty {
            groups.append(Group(id: "loose", shelf: .loose, label: "on their own", members: loose.sorted(by: byAge).map(\.id)))
        }
        if !done.isEmpty {
            groups.append(Group(id: "done", shelf: .done, label: "done", members: done.sorted { $0.updatedAt > $1.updatedAt }.map(\.id)))
        }
        for group in groups {
            for id in group.members { home[id] = group.id }
        }
    }

    func group(of drop: UUID) -> Group? {
        guard let id = home[drop] else { return nil }
        return groups.first { $0.id == id }
    }

    func changes(since previous: ClusterSnapshot) -> [ClusterChange] {
        var changes: [ClusterChange] = []
        let before = Dictionary(previous.groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let after = Dictionary(groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for group in previous.groups where after[group.id] == nil {
            if let into = majority(of: group.members, in: home) {
                changes.append(.merged(from: group.id, into: into))
            } else {
                changes.append(.dissolved(group: group.id))
            }
        }
        for group in groups {
            if let old = before[group.id] {
                if old.label != group.label {
                    changes.append(.relabeled(group: group.id, from: old.label, to: group.label))
                }
            } else if let parent = majority(of: group.members, in: previous.home), after[parent] != nil {
                changes.append(.split(from: parent, into: group.id))
            } else {
                changes.append(.formed(group: group.id))
            }
        }
        for group in groups {
            for id in group.members {
                if let from = previous.home[id] {
                    if from != group.id { changes.append(.moved(drop: id, from: from, to: group.id)) }
                } else {
                    changes.append(.arrived(drop: id, into: group.id))
                }
            }
        }
        return changes
    }

    private func majority(of members: [UUID], in homes: [UUID: String]) -> String? {
        var counts: [String: Int] = [:]
        for id in members {
            if let group = homes[id] { counts[group, default: 0] += 1 }
        }
        guard let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), best.value * 2 > counts.values.reduce(0, +) else { return nil }
        return best.key
    }

    private static func stableIds(for order: [String], members: [String: [UUID]], previous: ClusterSnapshot?) -> [String: String] {
        guard let previous else {
            return Dictionary(uniqueKeysWithValues: order.map { ($0, "cluster-\($0)") })
        }
        var ids: [String: String] = [:]
        var claimed = Set<String>()
        for clusterId in order {
            if let id = previous.visual[clusterId] {
                ids[clusterId] = id
                claimed.insert(id)
            }
        }
        let vanished = Set(previous.visual.values).subtracting(claimed)
        for clusterId in order where ids[clusterId] == nil {
            var counts: [String: Int] = [:]
            for id in members[clusterId] ?? [] {
                if let old = previous.home[id], vanished.contains(old), !claimed.contains(old) { counts[old, default: 0] += 1 }
            }
            let oldSize = { (group: String) in previous.groups.first { $0.id == group }?.members.count ?? 0 }
            if let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), best.value * 2 > oldSize(best.key) {
                ids[clusterId] = best.key
                claimed.insert(best.key)
            } else {
                var id = "cluster-\(clusterId)"
                while claimed.contains(id) { id += "+" }
                ids[clusterId] = id
                claimed.insert(id)
            }
        }
        return ids
    }

    private static func arrange(_ members: [UUID], pairs: [Pair]) -> [UUID] {
        let index = Dictionary(members.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var adjacent: [Int: [Int]] = [:]
        for pair in pairs {
            guard let a = index[pair.first], let b = index[pair.second] else { continue }
            adjacent[a, default: []].append(b)
            adjacent[b, default: []].append(a)
        }
        var seen = Set<Int>()
        var arranged: [Int] = []
        for start in members.indices where !seen.contains(start) {
            var queue = [start]
            seen.insert(start)
            while !queue.isEmpty {
                let current = queue.removeFirst()
                arranged.append(current)
                for next in (adjacent[current] ?? []).sorted() where !seen.contains(next) {
                    seen.insert(next)
                    queue.append(next)
                }
            }
        }
        return arranged.map { members[$0] }
    }

    private static func pairs(order: [UUID], cluster: [UUID: String], neighbors: [UUID: [DropNeighbor]]) -> [Pair] {
        var counts: [UUID: Int] = [:]
        var taken = Set<String>()
        var bridges = Set<String>()
        var result: [Pair] = []
        for rank in 0..<2 {
            for id in order {
                guard let home = cluster[id],
                      let list = neighbors[id], rank < list.count,
                      let other = UUID(uuidString: list[rank].clientId), other != id,
                      let away = cluster[other]
                else { continue }
                let key = [id.uuidString, other.uuidString].sorted().joined(separator: "|")
                guard !taken.contains(key), counts[id, default: 0] < 2, counts[other, default: 0] < 2 else { continue }
                if home != away {
                    let bridge = [home, away].sorted().joined(separator: "|")
                    guard !bridges.contains(bridge) else { continue }
                    bridges.insert(bridge)
                }
                taken.insert(key)
                counts[id, default: 0] += 1
                counts[other, default: 0] += 1
                result.append(Pair(id: key, first: id, second: other, reason: list[rank].reason))
            }
        }
        return result
    }
}

enum ClusterChange: Equatable {
    case arrived(drop: UUID, into: String)
    case moved(drop: UUID, from: String, to: String)
    case formed(group: String)
    case merged(from: String, into: String)
    case split(from: String, into: String)
    case relabeled(group: String, from: String, to: String)
    case dissolved(group: String)
}

enum ClusterMotion {
    static let drift: Animation = .spring(response: 0.62, dampingFraction: 0.84)
    static let makeRoom: Animation = .spring(response: 0.5, dampingFraction: 0.86)
    static let step = 0.09

    static func delays(for changes: [ClusterChange]) -> [UUID: Double] {
        var delays: [UUID: Double] = [:]
        for change in changes {
            guard case .moved(let drop, _, _) = change else { continue }
            delays[drop] = min(Double(delays.count) * step, 0.45)
        }
        return delays
    }
}
