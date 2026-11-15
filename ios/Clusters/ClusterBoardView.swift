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
    @State private var lastDeparture: Date = .distantPast
    @State private var committed: Committed?
    @State private var visible = Visible()
    @State private var touching = false
    @State private var boardWidth: CGFloat = 0
    @State private var chosenLink: String?
    @State private var settles = 0
    @State private var scroll = ScrollPosition()
    @State private var aimed = false

    private let mood = Mood.sunny
    private static let dwell: Duration = .milliseconds(1100)
    private static let departureGap = 0.45

    private struct Hold {
        let slot: Int
        let since: Date
    }

    private struct Committed {
        let snapshot: ClusterSnapshot
        let labels: [String: ClusterLayout.Label]
    }

    private struct Visible: Equatable {
        var rect: CGRect = .zero
        var top: CGFloat = 0
        var bottom: CGFloat = 0

        var band: ClosedRange<CGFloat> {
            let low = rect.minY + top
            return low...max(low, rect.maxY - bottom)
        }
    }

    private struct Ghost: Identifiable {
        let id: String
        let label: ClusterLayout.Label
        let to: CGPoint
    }

    private struct Flight {
        let start: CGSize
        let bulge: CGSize
        let curve: Animation
        let seconds: Double
        var progress: Double
    }

    private struct Plan {
        let snapshot: ClusterSnapshot
        let layout: ClusterLayout
        let changes: [ClusterChange]
        let delays: [UUID: Double]
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
            .task(id: plan.snapshot) { await settle(plan) }
            .onScrollGeometryChange(for: Visible.self, of: { Visible(rect: $0.visibleRect, top: $0.contentInsets.top, bottom: $0.contentInsets.bottom) }) { _, new in
                visible = new
            }
            .onScrollPhaseChange { _, phase in
                touching = phase == .tracking || phase == .interacting || phase == .decelerating
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
        let chosen = plan.layout.links.first { $0.id == chosenLink }
        return ZStack(alignment: .topLeading) {
            ForEach(plan.layout.links) { link in
                let live = shown.contains(link.first) && shown.contains(link.second)
                    && !calm.contains(link.first) && !calm.contains(link.second)
                strand(link, chosen: link.id == chosenLink)
                    .animation(move(after: max(plan.delays[link.first] ?? 0, plan.delays[link.second] ?? 0)), value: [link.from, link.control, link.to])
                    .opacity(live ? 1 : 0)
                    .allowsHitTesting(live)
                    .transition(.opacity)
            }

            ForEach(ghosts(plan)) { ghost in
                ClusterGhostLabel(label: ghost.label, to: ghost.to, animation: move(after: 0))
            }

            ForEach(plan.layout.labels) { label in
                ClusterLabelSlip(text: label.text)
                    .rotationEffect(.degrees(label.tilt))
                    .offset(x: label.origin.x, y: label.origin.y)
                    .transition(arrival(of: label, plan: plan))
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
        .frame(width: width, height: max(plan.layout.height, visible.rect.height), alignment: .topLeading)
        .animation(move(after: 0), value: dataKey)
    }

    private func move(after delay: Double) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : ClusterMotion.drift.delay(delay)
    }

    private func ghosts(_ plan: Plan) -> [Ghost] {
        guard let committed else { return [] }
        let now = Dictionary(plan.layout.labels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return plan.changes.compactMap { change in
            switch change {
            case .merged(let from, let into):
                guard let old = committed.labels[from] else { return nil }
                return Ghost(id: from, label: old, to: now[into]?.origin ?? old.origin)
            case .dissolved(let group):
                guard let old = committed.labels[group] else { return nil }
                return Ghost(id: group, label: old, to: old.origin)
            default:
                return nil
            }
        }
    }

    private func arrival(of label: ClusterLayout.Label, plan: Plan) -> AnyTransition {
        let parent = plan.changes.lazy.compactMap { change -> String? in
            guard case .split(let from, let into) = change, into == label.id else { return nil }
            return from
        }.first
        if !reduceMotion, let parent, let origin = plan.layout.labels.first(where: { $0.id == parent })?.origin {
            return .asymmetric(
                insertion: .offset(x: origin.x - label.origin.x, y: origin.y - label.origin.y).combined(with: .opacity),
                removal: .identity
            )
        }
        return .asymmetric(insertion: .scale(scale: 0.85, anchor: .topLeading).combined(with: .opacity), removal: .identity)
    }

    private func item(_ drop: Drop, shape: ClusterShape, point: CGPoint, plan: Plan, shown: Bool, lifted: Bool) -> some View {
        let spot = plan.layout.spots[drop.id]
        let flight = flights[drop.id]
        let start = lifted ? CGSize.zero : (flight?.start ?? .zero)
        let identity = reduceMotion && !lifted ? "\(drop.id)@\(Int(point.x)),\(Int(point.y))" : drop.id.uuidString
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
        .animation(lifted || flight != nil ? nil : move(after: plan.delays[drop.id] ?? 0), value: point)
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
        let now = clock.now
        var shapes: [UUID: ClusterShape] = [:]
        for drop in drops {
            shapes[drop.id] = ClusterShape(drop, now: now)
        }
        let snapshot = ClusterSnapshot(drops: drops.filter { !holding.contains($0.id) }, following: committed?.snapshot)
        let layout = ClusterLayout(snapshot, width: width) { id in
            let shape = shapes[id]
            return ClusterLayout.Member(id: id, size: shape?.size ?? .zero, faceHeight: shape?.face.height ?? 0)
        }
        let changes = committed.map { snapshot.changes(since: $0.snapshot) } ?? []
        var labels: [UUID: String] = [:]
        for group in snapshot.groups where group.shelf == .cluster {
            for id in group.members { labels[id] = group.label }
        }
        let titles = Dictionary(drops.map { ($0.id, $0.title?.lowercased() ?? $0.kind.word) }, uniquingKeysWith: { first, _ in first })
        var reasons: [UUID: [String]] = [:]
        for link in layout.links {
            reasons[link.first, default: []].append("goes with \(titles[link.second] ?? "a drop"): \(link.reason)")
            reasons[link.second, default: []].append("goes with \(titles[link.first] ?? "a drop"): \(link.reason)")
        }
        return Plan(snapshot: snapshot, layout: layout, changes: changes, delays: ClusterMotion.delays(for: changes), shapes: shapes, labels: labels, reasons: reasons)
    }

    private func settle(_ plan: Plan) async {
        let labels = Dictionary(plan.layout.labels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard committed != nil else {
            committed = Committed(snapshot: plan.snapshot, labels: labels)
            return
        }
        let focus = plan.changes.reversed().lazy.compactMap { change -> String? in
            switch change {
            case .moved(_, _, let to): to
            case .merged(_, let into): into
            case .split(_, let into): into
            default: nil
            }
        }.first
        if let focus, let frame = plan.layout.frames[focus] {
            follow(frame, height: plan.layout.height, animation: ClusterMotion.drift)
        }
        try? await Task.sleep(for: .milliseconds(1200))
        guard !Task.isCancelled else { return }
        committed = Committed(snapshot: plan.snapshot, labels: labels)
    }

    private func follow(_ rect: CGRect, height: CGFloat, animation: Animation) {
        guard !touching, !reduceMotion, visible.rect.height > 0 else { return }
        let band = visible.band
        let room = band.upperBound - band.lowerBound
        guard room > 0 else { return }
        let fits = rect.minY >= band.lowerBound && min(rect.maxY, rect.minY + room) <= band.upperBound
        guard !fits else { return }
        let y = rect.height < room ? rect.midY - room / 2 : rect.minY - 16
        withAnimation(animation) { scroll.scrollTo(y: min(max(y, 0), max(height - room, 0))) }
    }

    private func landingPoint(_ slot: Int, width: CGFloat) -> CGPoint {
        let band = visible.rect.height > 0 ? visible.band : 0...700
        let lane: CGFloat = [0, -1, 1][slot % 3]
        let x = min(max(width / 2 + lane * width * 0.27, 92), width - 92)
        let y = band.lowerBound + (band.upperBound - band.lowerBound) * 0.42 + (lane == 0 ? 0 : 34) + CGFloat(slot / 3) * 48
        return CGPoint(x: x, y: y)
    }

    private func slots() -> [UUID: Int] {
        var slots = held.mapValues(\.slot)
        let fresh = known.map { known in drops.filter { !known.contains($0.id) && held[$0.id] == nil } } ?? drops.filter(\.isArriving)
        guard known == nil || fresh.count <= 3 else { return slots }
        var used = Set(slots.values)
        for drop in fresh {
            var slot = 0
            while used.contains(slot) { slot += 1 }
            used.insert(slot)
            slots[drop.id] = slot
        }
        return slots
    }

    private func currentHolds(width: CGFloat) -> [UUID: CGPoint] {
        slots().mapValues { landingPoint($0, width: width) }
    }

    private var dataKey: Int {
        var hasher = Hasher()
        hasher.combine(filter)
        for drop in drops {
            hasher.combine(drop.id)
            hasher.combine(drop.statusRaw)
            hasher.combine(drop.zoneRaw)
            hasher.combine(drop.pinnedAt)
            hasher.combine(drop.clusterId)
            hasher.combine(drop.clusterLabel)
        }
        return hasher.finalize()
    }

    private var arrivalKey: Int {
        var hasher = Hasher()
        for drop in drops {
            hasher.combine(drop.id)
            hasher.combine(drop.statusRaw)
            hasher.combine(drop.clusterId)
        }
        return hasher.finalize()
    }

    private func reconcile() {
        let ids = Set(drops.map(\.id))
        let now = Date.now
        for (id, slot) in slots() where held[id] == nil {
            held[id] = Hold(slot: slot, since: now)
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
            let ready = drop.clusterId != nil
                || drop.status == .failed
                || drop.zone == .done
                || drop.isPinned
                || (drop.status == .processed && drop.vibes.isEmpty && waited >= 3)
            guard ready else { continue }
            let since = readySince[id] ?? now
            if readySince[id] == nil { readySince[id] = now }
            if waited >= 1.1, now.timeIntervalSince(since) >= 0.6, now.timeIntervalSince(lastDeparture) >= Self.departureGap { fly(id) }
        }
    }

    private func fly(_ id: UUID) {
        guard let hold = held[id], flights[id] == nil else { return }
        readySince[id] = nil
        lastDeparture = .now
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) { held[id] = nil }
            settles += 1
            return
        }
        var remaining = Set(held.keys)
        remaining.remove(id)
        let from = landingPoint(hold.slot, width: boardWidth)
        let plan = makePlan(width: boardWidth, holding: remaining)
        let spot = plan.layout.spots[id]
        let target = spot?.center ?? from
        let travel = CGSize(width: target.x - from.x, height: target.y - from.y)
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
            if let spot {
                follow(spot.frame, height: plan.layout.height, animation: .spring(duration: seconds, bounce: 0.12))
            }
            withAnimation(ClusterMotion.makeRoom) {
                held[id] = nil
                flights[id]?.progress = 1
            }
            try? await Task.sleep(for: .seconds(seconds + 0.15))
            withAnimation(.easeOut(duration: 0.3)) { flights[id] = nil }
            settles += 1
        }
    }
}
