import os
import SwiftUI

struct ClusterBoardView: View {
    let drops: [Drop]
    let namespace: Namespace.ID
    var filter: DropFilter = .everyone
    var me: String = DeviceIdentity.personId
    var select: (Drop) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardClock.self) private var clock
    @State private var known: Set<UUID>?
    @State private var held: [UUID: Hold] = [:]
    @State private var readySince: [UUID: Date] = [:]
    @State private var flights: [UUID: Flight] = [:]
    @State private var viewport: CGRect = .zero
    @State private var boardWidth: CGFloat = 0
    @State private var chosenLink: String?
    @State private var settles = 0
    @State private var scroll = ScrollPosition()
    @State private var aimed = false

    private let mood = Mood.sunny
    private static let dwell: Duration = .milliseconds(1100)
    private static let makeRoom: Animation = .spring(response: 0.5, dampingFraction: 0.86)

    private struct Hold {
        let point: CGPoint
        let since: Date
    }

    private struct Flight {
        let start: CGSize
        let bulge: CGSize
        let curve: Animation
        let seconds: Double
        var progress: Double
    }

    private struct Plan {
        let layout: ClusterLayout
        let links: [ClusterLayout.Link]
        let shapes: [UUID: ClusterShape]
        let labels: [UUID: String]
        let reasons: [UUID: [String]]
    }

    private static var debugAnchor: UnitPoint? {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "BoardDebugAnchor") == "bottom" { return .bottom }
        #endif
        return nil
    }

    private static var debugCluster: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "ClusterDebugCluster").map { "cluster-\($0)" }
        #else
        return nil
        #endif
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let holds = currentHolds(width: width)
            let plan = makePlan(width: width, holding: Set(holds.keys))
            ScrollView(.vertical) {
                board(plan, holds: holds, width: width)
                    .background {
                        CorkSurface()
                            .padding(.vertical, -400)
                            .contentShape(.rect)
                            .onTapGesture { choose(nil) }
                    }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(Self.debugAnchor)
            .scrollPosition($scroll)
            .task(id: plan.layout.labels.map { "\($0.id)@\(Int($0.origin.y))" }) {
                guard !aimed, let target = Self.debugCluster,
                      let label = plan.layout.labels.first(where: { $0.id == target })
                else { return }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                aimed = true
                scroll.scrollTo(y: max(label.origin.y - 12, 0))
            }
            .onScrollGeometryChange(for: CGRect.self, of: { $0.visibleRect }) { _, rect in
                viewport = rect
            }
            .onAppear { boardWidth = width }
            .onChange(of: width) { _, newWidth in boardWidth = newWidth }
        }
        .background(mood.board.ignoresSafeArea())
        .environment(\.mood, mood)
        .environment(\.colorScheme, .light)
        .task(id: arrivalKey) { reconcile() }
        .sensoryFeedback(.impact(weight: .light), trigger: settles)
        .accessibilityIdentifier("clusterBoard")
    }

    private func board(_ plan: Plan, holds: [UUID: CGPoint], width: CGFloat) -> some View {
        let shown = Set(drops.filter(isShown).map(\.id))
        let calm = Set(holds.keys).union(flights.keys)
        let chosen = plan.links.first { $0.id == chosenLink }
        return ZStack(alignment: .topLeading) {
            ForEach(plan.links) { link in
                let live = shown.contains(link.first) && shown.contains(link.second)
                    && !calm.contains(link.first) && !calm.contains(link.second)
                strand(link, chosen: link.id == chosenLink)
                    .opacity(live ? 1 : 0)
                    .allowsHitTesting(live)
                    .transition(.opacity)
            }

            ForEach(plan.layout.labels) { label in
                ClusterLabelSlip(text: label.text)
                    .rotationEffect(.degrees(label.tilt))
                    .offset(x: label.origin.x, y: label.origin.y)
                    .accessibilitySortPriority(-Double(label.order) * 1000)
                    .accessibilityIdentifier("clusterLabel-\(label.id)")
            }

            ForEach(drops) { drop in
                if let shape = plan.shapes[drop.id],
                   let point = holds[drop.id] ?? plan.layout.spots[drop.id]?.center {
                    item(drop, shape: shape, point: point, plan: plan, shown: shown.contains(drop.id), lifted: holds[drop.id] != nil)
                }
            }

            if let chosen, shown.contains(chosen.first), shown.contains(chosen.second) {
                ClusterReasonNote(text: chosen.reason)
                    .rotationEffect(.degrees(-1))
                    .position(x: min(max(chosen.anchor.x, 136), width - 136), y: chosen.anchor.y - 34)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: width, height: max(plan.layout.height, viewport.height), alignment: .topLeading)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : mood.move, value: dataKey)
    }

    private func item(_ drop: Drop, shape: ClusterShape, point: CGPoint, plan: Plan, shown: Bool, lifted: Bool) -> some View {
        let spot = plan.layout.spots[drop.id]
        let flight = flights[drop.id]
        let start = lifted ? CGSize.zero : (flight?.start ?? .zero)
        let identity = reduceMotion ? "\(drop.id)@\(Int(point.x)),\(Int(point.y))" : drop.id.uuidString
        return ClusterItem(
            drop: drop,
            shape: shape,
            clusterLabel: plan.labels[drop.id],
            reasons: plan.reasons[drop.id] ?? [],
            namespace: namespace,
            morphs: !reduceMotion,
            select: select
        )
        .scaleEffect(lifted ? 1.06 : 1)
        .shadow(color: mood.shade.opacity(lifted ? 0.22 : 0), radius: 18, y: 14)
        .rotationEffect(.degrees(spot?.tilt ?? 0))
        .position(point)
        .transaction { if flight != nil { $0.animation = nil } }
        .animation(flight?.curve ?? .default) {
            $0.modifier(ArcFlight(progress: flight?.progress ?? 1, start: start, bulge: flight?.bulge ?? .zero))
        }
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .accessibilitySortPriority(-Double(spot?.order ?? -1) - 0.5)
        .zIndex(lifted || flight != nil ? 3 : 1)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .id(identity)
    }

    private func strand(_ link: ClusterLayout.Link, chosen: Bool) -> some View {
        ZStack {
            ClusterString(link: link)
                .stroke(chosen ? mood.personDeep : mood.person, style: StrokeStyle(lineWidth: chosen ? 3.5 : 2.5, lineCap: .round))
            ClusterString(link: link)
                .stroke(mood.personDeep, style: StrokeStyle(lineWidth: chosen ? 3.5 : 2.5, lineCap: .butt, dash: [1.5, 9]))
        }
        .contactShadow(mood)
        .overlay {
            Color.clear
                .contentShape(ClusterStringHitArea(link: link))
                .onTapGesture { choose(chosenLink == link.id ? nil : link.id) }
        }
        .accessibilityElement()
        .accessibilityLabel("string")
        .accessibilityValue(link.reason)
        .accessibilityHidden(true)
    }

    private func choose(_ id: String?) {
        guard chosenLink != id else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy) { chosenLink = id }
    }

    private func isShown(_ drop: Drop) -> Bool {
        filter == .everyone || drop.authorId == me
    }

    private func makePlan(width: CGFloat, holding: Set<UUID>) -> Plan {
        let facts = Dictionary(drops.map { ($0.id, ClusterFacts($0)) }, uniquingKeysWith: { first, _ in first })
        let now = clock.now
        var shapes: [UUID: ClusterShape] = [:]
        for drop in drops {
            shapes[drop.id] = ClusterShape(drop, now: now)
        }
        func member(_ drop: Drop) -> ClusterLayout.Member {
            let shape = shapes[drop.id] ?? ClusterShape(drop, now: now)
            return ClusterLayout.Member(id: drop.id, size: shape.size, faceHeight: shape.face.height)
        }
        let byAge: (Drop, Drop) -> Bool = { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }

        var pinned: [Drop] = []
        var loose: [Drop] = []
        var done: [Drop] = []
        var clusters: [String: [Drop]] = [:]
        var born: [String: Date] = [:]
        for drop in drops {
            let clusterId = drop.zone == .done ? nil : facts[drop.id]?.clusterId
            if let clusterId {
                born[clusterId] = min(born[clusterId] ?? .distantFuture, drop.createdAt)
            }
            guard !holding.contains(drop.id) else { continue }
            if drop.zone == .done {
                done.append(drop)
            } else if drop.isPinned {
                pinned.append(drop)
            } else if let clusterId {
                clusters[clusterId, default: []].append(drop)
            } else {
                loose.append(drop)
            }
        }

        var groups: [ClusterLayout.Group] = []
        var labels: [UUID: String] = [:]
        var pairOrder: [UUID] = []
        var home: [UUID: String] = [:]
        if !pinned.isEmpty {
            let sorted = pinned.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
            groups.append(ClusterLayout.Group(id: "pinned", label: "pinned", shelf: .pinned, members: sorted.map(member)))
        }
        let clusterOrder = clusters.keys.sorted { ((born[$0] ?? .distantFuture), $0) < ((born[$1] ?? .distantFuture), $1) }
        for clusterId in clusterOrder {
            let members = (clusters[clusterId] ?? []).sorted(by: byAge)
            let label = members.reversed().lazy.compactMap { CardWords.clean(facts[$0.id]?.clusterLabel) }.first ?? "together"
            for drop in members {
                labels[drop.id] = label
                pairOrder.append(drop.id)
                home[drop.id] = clusterId
            }
            groups.append(ClusterLayout.Group(id: "cluster-\(clusterId)", label: label, shelf: .cluster, members: members.map(member)))
        }
        if !loose.isEmpty {
            groups.append(ClusterLayout.Group(id: "loose", label: "on their own", shelf: .loose, members: loose.sorted(by: byAge).map(member)))
        }
        if !done.isEmpty {
            groups.append(ClusterLayout.Group(id: "done", label: "done", shelf: .done, members: done.sorted { $0.updatedAt > $1.updatedAt }.map(member)))
        }

        let pairs = ClusterLayout.pairs(order: pairOrder, cluster: home, neighbors: facts.mapValues(\.neighbors))
        let layout = ClusterLayout(groups: groups, pairs: pairs, width: width)
        let links = layout.links(pairs)
        let titles = Dictionary(drops.map { ($0.id, $0.title?.lowercased() ?? $0.kind.word) }, uniquingKeysWith: { first, _ in first })
        var reasons: [UUID: [String]] = [:]
        for link in links {
            reasons[link.first, default: []].append("goes with \(titles[link.second] ?? "a drop"): \(link.reason)")
            reasons[link.second, default: []].append("goes with \(titles[link.first] ?? "a drop"): \(link.reason)")
        }
        return Plan(layout: layout, links: links, shapes: shapes, labels: labels, reasons: reasons)
    }

    private func landingPoint(_ index: Int, width: CGFloat) -> CGPoint {
        let area = viewport.height > 0 ? viewport : CGRect(x: 0, y: 0, width: width, height: 700)
        let spread = CGFloat(index)
        return CGPoint(x: area.midX + spread * 28 - 14 * min(spread, 1), y: area.minY + area.height * 0.5 + spread * 32)
    }

    private func currentHolds(width: CGFloat) -> [UUID: CGPoint] {
        var holds = held.mapValues(\.point)
        guard let known else {
            for (index, drop) in drops.filter(\.isArriving).enumerated() {
                holds[drop.id] = landingPoint(index, width: width)
            }
            return holds
        }
        let fresh = drops.filter { !known.contains($0.id) && holds[$0.id] == nil }
        if fresh.count <= 3 {
            for (index, drop) in fresh.enumerated() {
                holds[drop.id] = landingPoint(held.count + index, width: width)
            }
        }
        return holds
    }

    private var dataKey: Int {
        var hasher = Hasher()
        hasher.combine(filter)
        for drop in drops {
            hasher.combine(drop.id)
            hasher.combine(drop.statusRaw)
            hasher.combine(drop.zoneRaw)
            hasher.combine(drop.pinnedAt)
            hasher.combine(ClusterFacts(drop).clusterId)
        }
        return hasher.finalize()
    }

    private var arrivalKey: Int {
        var hasher = Hasher()
        for drop in drops {
            hasher.combine(drop.id)
            hasher.combine(drop.statusRaw)
            hasher.combine(ClusterFacts(drop).clusterId)
        }
        return hasher.finalize()
    }

    private func reconcile() {
        let ids = Set(drops.map(\.id))
        let holds = currentHolds(width: boardWidth)
        let now = Date.now
        for (id, point) in holds where held[id] == nil {
            held[id] = Hold(point: point, since: now)
            watch(id)
        }
        held = held.filter { ids.contains($0.key) }
        known = ids
        releaseReady()
    }

    private func watch(_ id: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: Self.dwell)
            for _ in 0..<48 {
                guard held[id] != nil else { return }
                releaseReady()
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard held[id] != nil else { return }
            Logger.app.error("drop \(id.uuidString, privacy: .public) waited too long for its cluster, so it goes on its own")
            fly(id)
        }
    }

    private func releaseReady() {
        let now = Date.now
        for (id, hold) in held {
            let waited = now.timeIntervalSince(hold.since)
            guard flights[id] == nil, let drop = drops.first(where: { $0.id == id }) else { continue }
            let facts = ClusterFacts(drop)
            let ready = facts.clusterId != nil
                || drop.status == .failed
                || drop.zone == .done
                || drop.isPinned
                || (drop.status == .processed && facts.vibes.isEmpty && waited >= 3)
            guard ready else { continue }
            let since = readySince[id] ?? now
            if readySince[id] == nil { readySince[id] = now }
            if waited >= 1.1, now.timeIntervalSince(since) >= 0.6 { fly(id) }
        }
    }

    private func fly(_ id: UUID) {
        guard let hold = held[id], flights[id] == nil else { return }
        readySince[id] = nil
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) { held[id] = nil }
            settles += 1
            return
        }
        var remaining = Set(held.keys)
        remaining.remove(id)
        let target = makePlan(width: boardWidth, holding: remaining).layout.spots[id]?.center ?? hold.point
        let travel = CGSize(width: target.x - hold.point.x, height: target.y - hold.point.y)
        let distance = max(hypot(travel.width, travel.height), 1)
        let swing = min(90, distance * 0.2)
        let side: CGFloat = travel.height >= 0 ? 1 : -1
        let bulge = CGSize(width: -travel.height / distance * swing * 4 * side, height: travel.width / distance * swing * 4 * side)
        let seconds = 0.55 + min(0.45, Double(distance) / 2500)
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            flights[id] = Flight(
                start: CGSize(width: -travel.width, height: -travel.height),
                bulge: bulge,
                curve: .spring(duration: seconds, bounce: 0.12),
                seconds: seconds,
                progress: 0
            )
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(Self.makeRoom) {
                held[id] = nil
                flights[id]?.progress = 1
            }
            try? await Task.sleep(for: .seconds(seconds + 0.15))
            withAnimation(.easeOut(duration: 0.3)) { flights[id] = nil }
            settles += 1
        }
    }
}
