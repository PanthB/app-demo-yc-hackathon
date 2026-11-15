import os
import SwiftUI

struct ConstellationGeometry {
    struct Group: Sendable {
        let id: String
        let label: String
        let members: [UUID]
    }

    struct Cluster: Identifiable, Sendable {
        let id: String
        let label: String
        let center: CGPoint
        let radius: CGFloat
        let members: [UUID]
    }

    static let ringStep: CGFloat = 74
    static let ringCapacity = [1, 6, 12, 18]
    static let padding: CGFloat = 40
    static let labelRoom: CGFloat = 26
    static let gap: CGFloat = 10

    private(set) var points: [UUID: CGPoint] = [:]
    private(set) var clusters: [Cluster] = []
    private(set) var size: CGSize = .zero

    init(groups: [Group], links: [LayoutLink], width: CGFloat) {
        let groups = groups.filter { !$0.members.isEmpty }
        var previous: (center: CGPoint, reach: CGFloat)?
        var side: CGFloat = -1
        var bottom: CGFloat = 0
        for group in groups {
            let ordered = Self.arrange(group.members, links: links)
            let offsets = Self.rings(ordered)
            let rings = Self.ringCount(ordered.count)
            let radius = CGFloat(max(rings - 1, 0)) * Self.ringStep + Self.padding
            let reach = radius + Self.labelRoom
            let swing = groups.count > 1 ? max(0, min(width * 0.22, width / 2 - radius - 4)) : 0
            let x = width / 2 + side * swing
            var y = reach
            if let previous {
                let dx = abs(x - previous.center.x)
                let need = previous.reach + reach + Self.gap
                y = previous.center.y + max(sqrt(max(need * need - dx * dx, 0)), radius + Self.labelRoom)
            }
            let center = CGPoint(x: x, y: y)
            for (id, offset) in offsets {
                points[id] = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            }
            clusters.append(Cluster(id: group.id, label: group.label, center: center, radius: radius, members: ordered))
            bottom = max(bottom, y + radius)
            previous = (center, reach)
            side *= -1
        }
        size = CGSize(width: width, height: bottom + 12)
    }

    init(field: ClusterField, groups: [Group]) {
        size = field.size
        for group in groups {
            guard let center = field.center(of: group.id) else { continue }
            clusters.append(Cluster(id: group.id, label: group.label, center: center, radius: field.radii[group.id] ?? ClusterField.spacing, members: group.members))
            for id in group.members {
                points[id] = field.position(of: id)
            }
        }
    }

    static func ringCount(_ count: Int) -> Int {
        var placed = 0
        var ring = 0
        while placed < count {
            placed += capacity(ring)
            ring += 1
        }
        return ring
    }

    static func capacity(_ ring: Int) -> Int {
        ring < ringCapacity.count ? ringCapacity[ring] : 6 * ring
    }

    static func rings(_ ordered: [UUID]) -> [UUID: CGPoint] {
        var offsets: [UUID: CGPoint] = [:]
        var index = 0
        var ring = 0
        while index < ordered.count {
            let count = min(capacity(ring), ordered.count - index)
            let radius = CGFloat(ring) * ringStep
            let step = 2 * Double.pi / Double(max(count, 1))
            let start = -Double.pi / 2 + (ring.isMultiple(of: 2) ? step / 2 : 0)
            for slot in 0..<count {
                let angle = start + step * Double(slot)
                offsets[ordered[index + slot]] = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
            }
            index += count
            ring += 1
        }
        return offsets
    }

    static func arrange(_ members: [UUID], links: [LayoutLink]) -> [UUID] {
        let inGroup = Set(members)
        var adjacent: [UUID: Set<UUID>] = [:]
        for link in links where inGroup.contains(link.first) && inGroup.contains(link.second) {
            adjacent[link.first, default: []].insert(link.second)
            adjacent[link.second, default: []].insert(link.first)
        }
        var seen = Set<UUID>()
        var result: [UUID] = []
        for start in members where !seen.contains(start) {
            var queue = [start]
            seen.insert(start)
            while !queue.isEmpty {
                let current = queue.removeFirst()
                result.append(current)
                for next in members where adjacent[current]?.contains(next) == true && !seen.contains(next) {
                    seen.insert(next)
                    queue.append(next)
                }
            }
        }
        return result
    }
}

struct ConstellationView: View {
    let drops: [Drop]
    let namespace: Namespace.ID
    let open: (Drop) -> Void

    @Environment(BoardClock.self) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: UUID?
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var drag: CGSize = .zero
    @State private var collapsed = false
    @State private var appeared = false
    @State private var viewport: CGSize = .zero
    @State private var known: Set<UUID>?
    @State private var held: [UUID: Date] = [:]
    @State private var flights: [UUID: Flight] = [:]
    @State private var toast: String?
    @State private var settles = 0
    @State private var snapshot: ClusterSnapshot?
    @State private var field: ClusterField?

    private static let node: CGFloat = 58
    private static let top: CGFloat = 28
    private static let dwell = 1.1
    private static let makeRoom: Animation = .spring(response: 0.5, dampingFraction: 0.86)

    private struct Flight {
        let target: CGPoint
        let start: CGSize
        let bulge: CGSize
        let curve: Animation
        var progress: Double
    }

    private struct Frame {
        let geometry: ConstellationGeometry
        let scale: CGFloat
        let fit: CGFloat
        let size: CGSize
        let offset: CGSize

        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: size.width / 2 + (point.x - geometry.size.width / 2) * scale + offset.width,
                y: ConstellationView.top + (size.height - ConstellationView.top) / 2 + (point.y - geometry.size.height / 2) * scale + offset.height
            )
        }

        var landing: CGPoint {
            CGPoint(x: size.width / 2, y: size.height * 0.56)
        }
    }

    var body: some View {
        let now = clock.now
        let shown = drops.filter { $0.boardZone(now: now) != .done }
        let settled = shown.filter { held[$0.id] == nil }
        let landingOrder = shown.filter { held[$0.id] != nil && flights[$0.id] == nil }.sorted { $0.createdAt < $1.createdAt }.map(\.id)
        let plan = Self.plan(settled, now: now, view: Self.view(viewport), snapshot: snapshot, field: field)
        let byId = Dictionary(drops.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        GeometryReader { proxy in
            let frame = frame(plan, size: proxy.size, live: true)
            let geometry = frame.geometry
            let related = Set(plan.links.filter { $0.touches(selected) }.map { $0.other(than: selected ?? UUID()) })

            ZStack {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(LayoutMotion.select(reduceMotion)) { selected = nil } }

                Canvas { context, _ in
                    for cluster in geometry.clusters {
                        let center = frame.place(cluster.center)
                        let radius = (collapsed ? Self.collapsedRadius(cluster) : cluster.radius) * frame.scale
                        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                        context.stroke(ring, with: .color(.white.opacity(collapsed ? 0.16 : 0.08)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    }
                    guard !collapsed, appeared else { return }
                    for link in plan.links {
                        guard flights[link.first] == nil, flights[link.second] == nil,
                              let a = geometry.points[link.first], let b = geometry.points[link.second] else { continue }
                        let curve = Self.curve(from: frame.place(a), to: frame.place(b))
                        let lit = link.touches(selected)
                        let color: Color = lit ? .white.opacity(0.9) : .white.opacity(selected == nil ? 0.26 : 0.06)
                        let dash: [CGFloat] = link.isTrail ? [1, 5] : (plan.cluster[link.first] != plan.cluster[link.second] ? [5, 5] : [])
                        context.stroke(curve.path, with: .color(color), style: StrokeStyle(lineWidth: lit ? 1.6 : 1, lineCap: .round, dash: dash))
                    }
                }
                .allowsHitTesting(false)
                .animation(Self.makeRoom, value: settles)

                ForEach(geometry.clusters) { cluster in
                    let center = frame.place(cluster.center)
                    let top = (collapsed ? Self.collapsedRadius(cluster) : cluster.radius) * frame.scale + 12
                    clusterLabel(cluster)
                        .scaleEffect(collapsed ? 1.15 : 1)
                        .position(x: min(max(center.x, 96), proxy.size.width - 96), y: collapsed ? center.y + top + 4 : max(center.y - top, 12))
                        .opacity(appeared ? 1 : 0)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }

                ForEach(shown) { drop in
                    let flight = flights[drop.id]
                    let landed = held[drop.id] != nil && flight == nil
                    let cluster = plan.cluster[drop.id]
                    let home = geometry.clusters.first { $0.id == cluster }
                    let order = home?.members.firstIndex(of: drop.id) ?? 0
                    if landed || flight != nil || geometry.points[drop.id] != nil {
                        let resting = geometry.points[drop.id].map { collapsed ? Self.stacked(home?.center ?? $0, order: order) : $0 } ?? .zero
                        let origin = home.map { frame.place($0.center) } ?? frame.landing
                        let spot = landed ? Self.landingSpot(frame, index: landingOrder.firstIndex(of: drop.id) ?? 0) : (flight?.target ?? frame.place(resting))
                        let size = landed ? Self.node * 1.25 : Self.node * frame.scale * (drop.isPinned ? 1.12 : 1) * (collapsed ? 1.2 : 1)
                        node(drop, size: size, related: related)
                            .background {
                                if landed { Reading(drop: drop, size: size) }
                            }
                            .rotationEffect(.degrees(collapsed && !landed ? Self.fan(order) : 0))
                            .opacity(collapsed && !landed && flight == nil && order > 2 ? 0 : 1)
                            .scaleEffect(appeared || reduceMotion || landed ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                            .position(appeared || reduceMotion || landed ? spot : origin)
                            .transaction { if flight != nil { $0.animation = nil } }
                            .animation(flight?.curve ?? .default) {
                                $0.modifier(ArcFlight(progress: flight?.progress ?? 1, start: flight?.start ?? .zero, bulge: flight?.bulge ?? .zero))
                            }
                            .animation(LayoutMotion.arrive(reduceMotion, delay: Double(order) * 0.035 + Double(geometry.clusters.firstIndex { $0.id == cluster } ?? 0) * 0.08), value: appeared)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.5).combined(with: .opacity))
                            .zIndex(landed || flight != nil ? 5 : (collapsed ? Double(10 - order) : (selected == drop.id ? 2 : 1)))
                    }
                }

                if !collapsed, let selected, appeared {
                    ForEach(plan.links.filter { $0.touches(selected) }) { link in
                        if let a = geometry.points[selected], let b = geometry.points[link.other(than: selected)] {
                            Text(link.reason)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(NightStyle.ink.opacity(0.88), in: .capsule)
                                .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
                                .fixedSize()
                                .position(Self.chip(from: frame.place(a), to: frame.place(b)))
                                .transition(.opacity)
                                .zIndex(3)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(.rect)
            .clipped()
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in pinched(to: zoom * value.magnification, frame: frame) }
                    .simultaneously(with: DragGesture(minimumDistance: 12)
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            pan.width += value.translation.width
                            pan.height += value.translation.height
                            withAnimation(LayoutMotion.settle(reduceMotion)) {
                                pan = Self.clamp(pan, content: geometry.size, scale: frame.fit * zoom, view: proxy.size)
                            }
                        })
            )
            .onAppear {
                viewport = proxy.size
                guard !appeared else { return }
                appeared = true
            }
            .onChange(of: proxy.size) { _, size in viewport = size }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("constellation")
            .accessibilityAction(named: collapsed ? "show every drop" : "show only the groups") {
                withAnimation(LayoutMotion.settle(reduceMotion)) { collapsed.toggle() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if let selected, let drop = byId[selected] {
                    LayoutFocusPanel(drop: drop, lines: lines(for: drop, links: plan.links, byId: byId)) {
                        open(drop)
                    } close: {
                        withAnimation(LayoutMotion.select(reduceMotion)) { self.selected = nil }
                    }
                    .padding(.horizontal, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 10)
                        .id(toast)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .accessibilityIdentifier("layoutToast")
                } else {
                    LayoutLegend(text: collapsed ? plan.collapsedLegend : plan.legend)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }
            }
            .animation(LayoutMotion.settle(reduceMotion), value: selected)
            .animation(LayoutMotion.settle(reduceMotion), value: toast)
        }
        .task(id: arrivalKey) { reconcile() }
        .onChange(of: chainKey, initial: true) {
            let settled = drops.filter { $0.boardZone(now: clock.now) != .done && held[$0.id] == nil }
            let next = Self.plan(settled, now: clock.now, view: Self.view(viewport), snapshot: snapshot, field: field)
            snapshot = next.snapshot
            field = next.field
        }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.impact(weight: .medium), trigger: collapsed)
        .sensoryFeedback(.impact(weight: .light), trigger: held.count)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: settles)
    }

    private func frame(_ plan: Plan, size: CGSize, live: Bool) -> Frame {
        let geometry = plan.field.map { ConstellationGeometry(field: $0, groups: plan.groups) }
            ?? ConstellationGeometry(groups: plan.groups, links: plan.links, width: size.width)
        let fit = min(1, (size.height - Self.top - 8) / max(geometry.size.height, 1), (size.width - 16) / max(geometry.size.width, 1))
        let scale = fit * zoom * (live ? pinch : 1)
        let offset = live ? CGSize(width: pan.width + drag.width, height: pan.height + drag.height) : pan
        return Frame(geometry: geometry, scale: scale, fit: fit, size: size, offset: offset)
    }

    private var chainKey: Int {
        var hasher = Hasher()
        hasher.combine(viewport.width)
        hasher.combine(viewport.height)
        for drop in drops where held[drop.id] == nil {
            hasher.combine(drop.id)
            hasher.combine(drop.clusterId)
            hasher.combine(drop.clusterLabel)
            hasher.combine(drop.pinnedAt)
            hasher.combine(drop.zoneRaw)
        }
        return hasher.finalize()
    }

    private static func view(_ size: CGSize) -> CGSize {
        size.width > 0 && size.height > 0 ? size : CGSize(width: 402, height: 640)
    }

    static func plane(for snapshot: ClusterSnapshot, view: CGSize) -> CGSize {
        let area = snapshot.groups.reduce(CGFloat(0)) { total, group in
            let radius = ClusterField.spacing * (0.5 + 0.9 * CGFloat(group.members.count).squareRoot())
            let side = radius * 2 + ClusterField.gap
            return total + side * side
        } * 1.2
        let ratio = view.height / max(view.width, 1)
        let width = max(view.width, (area / ratio).squareRoot())
        return CGSize(width: width, height: width * ratio)
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
        held = held.filter { ids.contains($0.key) }
        guard let known else {
            known = ids
            return
        }
        let fresh = drops.filter { !known.contains($0.id) && held[$0.id] == nil }
        self.known = ids
        guard !fresh.isEmpty, fresh.count <= 3 else {
            releaseReady()
            return
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.25)) {
            for drop in fresh { held[drop.id] = .now }
            if let newest = fresh.last {
                toast = "\(newest.authorLabel) added \(Self.article(newest.kind))."
            }
        }
        for drop in fresh { watch(drop.id) }
        let shownToast = toast
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toast == shownToast { toast = nil }
        }
    }

    private func watch(_ id: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.dwell))
            for _ in 0..<48 {
                guard held[id] != nil else { return }
                releaseReady()
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard held[id] != nil else { return }
            Logger.app.error("drop \(id.uuidString, privacy: .public) waited too long to be read, so it joins the board on its own")
            fly(id)
        }
    }

    private func releaseReady() {
        let now = Date.now
        for (id, since) in held where flights[id] == nil {
            guard let drop = drops.first(where: { $0.id == id }) else { continue }
            let waited = now.timeIntervalSince(since)
            let ready = drop.clusterId != nil
                || drop.status == .failed
                || drop.isPinned
                || (drop.status == .processed && (drop.vibes.isEmpty || waited >= 3))
            if ready, waited >= Self.dwell { fly(id) }
        }
    }

    private func fly(_ id: UUID) {
        guard held[id] != nil, flights[id] == nil else { return }
        if reduceMotion || viewport == .zero {
            withAnimation(.easeInOut(duration: 0.25)) {
                held[id] = nil
                settles += 1
            }
            return
        }
        let now = clock.now
        let waiting = drops.filter { held[$0.id] != nil && flights[$0.id] == nil }.sorted { $0.createdAt < $1.createdAt }
        let shown = drops.filter { $0.boardZone(now: now) != .done && (held[$0.id] == nil || $0.id == id) }
        let after = frame(Self.plan(shown, now: now, view: Self.view(viewport), snapshot: snapshot, field: field), size: viewport, live: false)
        let from = Self.landingSpot(after, index: waiting.firstIndex { $0.id == id } ?? 0)
        guard let point = after.geometry.points[id] else {
            withAnimation(Self.makeRoom) { held[id] = nil }
            return
        }
        let home = after.geometry.clusters.first { $0.members.contains(id) }
        let order = home?.members.firstIndex(of: id) ?? 0
        let target = after.place(collapsed ? Self.stacked(home?.center ?? point, order: order) : point)
        let travel = CGSize(width: target.x - from.x, height: target.y - from.y)
        let distance = max(hypot(travel.width, travel.height), 1)
        let swing = min(90, distance * 0.2)
        let side: CGFloat = travel.height >= 0 ? 1 : -1
        let bulge = CGSize(width: -travel.height / distance * swing * 4 * side, height: travel.width / distance * swing * 4 * side)
        let seconds = 0.55 + min(0.45, Double(distance) / 2500)
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            flights[id] = Flight(target: target, start: CGSize(width: -travel.width, height: -travel.height), bulge: bulge, curve: .spring(duration: seconds, bounce: 0.12), progress: 0)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(Self.makeRoom) {
                held[id] = nil
                flights[id]?.progress = 1
                settles += 1
            }
            try? await Task.sleep(for: .seconds(seconds + 0.15))
            flights[id] = nil
        }
    }

    private static func landingSpot(_ frame: Frame, index: Int) -> CGPoint {
        CGPoint(x: frame.landing.x + CGFloat(index) * 30, y: frame.landing.y + CGFloat(index) * 26)
    }

    private func node(_ drop: Drop, size: CGFloat, related: Set<UUID>) -> some View {
        let dim = !collapsed && selected != nil && selected != drop.id && !related.contains(drop.id)
        return Button {
            tap(drop)
        } label: {
            LayoutBadge(drop: drop, size: size)
                .scaleEffect(selected == drop.id ? 1.2 : 1)
                .animation(LayoutMotion.select(reduceMotion), value: selected)
        }
        .buttonStyle(NightPressStyle())
        .matchedTransitionSource(id: drop.id, in: namespace)
        .contextMenu { NightDropMenu(drop: drop) }
        .opacity(dim ? 0.3 : 1)
        .accessibilityLabel(drop.spokenLabel(now: clock.now, beside: .plain))
        .accessibilityIdentifier("layoutNode")
    }

    private func clusterLabel(_ cluster: ConstellationGeometry.Cluster) -> some View {
        HStack(spacing: 6) {
            Text(cluster.label).font(.subheadline.weight(.semibold))
            Text("\(cluster.members.count)")
                .font(.subheadline)
                .foregroundStyle(NightStyle.tertiary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .fixedSize()
        .onTapGesture {
            guard collapsed else { return }
            withAnimation(LayoutMotion.settle(reduceMotion)) { collapsed = false }
        }
        .accessibilityIdentifier("clusterLabel")
    }

    private func tap(_ drop: Drop) {
        if collapsed {
            withAnimation(LayoutMotion.settle(reduceMotion)) {
                collapsed = false
                selected = drop.id
            }
            return
        }
        if selected == drop.id {
            open(drop)
            return
        }
        withAnimation(LayoutMotion.select(reduceMotion)) { selected = drop.id }
    }

    private func pinched(to next: CGFloat, frame: Frame) {
        withAnimation(LayoutMotion.settle(reduceMotion)) {
            if !collapsed && next < 0.78 {
                collapsed = true
                selected = nil
                zoom = 1
                pan = .zero
            } else if collapsed && next > 1.2 {
                collapsed = false
                zoom = 1
            } else {
                zoom = collapsed ? 1 : min(max(next, 1), 2.6)
                pan = Self.clamp(pan, content: frame.geometry.size, scale: frame.fit * zoom, view: frame.size)
            }
        }
    }

    private func lines(for drop: Drop, links: [LayoutLink], byId: [UUID: Drop]) -> [String] {
        links.filter { $0.touches(drop.id) && !$0.isTrail }.prefix(2).compactMap { link in
            guard let other = byId[link.other(than: drop.id)] else { return nil }
            return "goes with \(other.layoutTitle). \(link.reason)"
        }
    }

    static func article(_ kind: DropKind) -> String {
        switch kind {
        case .event: "an event"
        case .photo: "a photo"
        case .video: "a clip"
        case .song: "a song"
        case .place: "a place"
        case .link: "a link"
        case .note: "a note"
        case .voice: "a voice note"
        case .reminder: "a reminder"
        }
    }

    static func clamp(_ pan: CGSize, content: CGSize, scale: CGFloat, view: CGSize) -> CGSize {
        let spareX = max(0, (content.width * scale - view.width) / 2 + 24)
        let spareY = max(0, (content.height * scale - view.height) / 2 + 24)
        return CGSize(width: min(max(pan.width, -spareX), spareX), height: min(max(pan.height, -spareY), spareY))
    }

    static func collapsedRadius(_ cluster: ConstellationGeometry.Cluster) -> CGFloat {
        min(cluster.radius, 46 + CGFloat(cluster.members.count) * 3)
    }

    static func stacked(_ center: CGPoint, order: Int) -> CGPoint {
        let spread: [CGFloat] = [0, -16, 16]
        return CGPoint(x: center.x + (order < 3 ? spread[order] : 0), y: center.y + (order == 0 ? -4 : 2))
    }

    static func fan(_ order: Int) -> Double {
        [0, -9, 9][min(order, 2)]
    }

    static func chip(from a: CGPoint, to b: CGPoint) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * 0.62, y: a.y + (b.y - a.y) * 0.62)
    }

    static func curve(from a: CGPoint, to b: CGPoint) -> (path: Path, middle: CGPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let bend: CGFloat = 0.14
        let control = CGPoint(x: (a.x + b.x) / 2 - dy * bend, y: (a.y + b.y) / 2 + dx * bend)
        var path = Path()
        path.move(to: a)
        path.addQuadCurve(to: b, control: control)
        let middle = CGPoint(x: 0.25 * a.x + 0.5 * control.x + 0.25 * b.x, y: 0.25 * a.y + 0.5 * control.y + 0.25 * b.y)
        return (path, middle)
    }

    struct Plan {
        var groups: [ConstellationGeometry.Group] = []
        var links: [LayoutLink] = []
        var cluster: [UUID: String] = [:]
        var legend = ""
        var collapsedLegend = ""
        var snapshot: ClusterSnapshot?
        var field: ClusterField?
    }

    static func plan(_ drops: [Drop], now: Date, view: CGSize, snapshot previous: ClusterSnapshot?, field previousField: ClusterField?) -> Plan {
        var plan = Plan()
        if drops.contains(where: { $0.clusterId != nil }) {
            let snapshot = ClusterSnapshot(drops: drops, following: previous)
            let field = ClusterField(snapshot, size: plane(for: snapshot, view: view), following: previousField)
            for group in snapshot.groups where group.shelf != .done {
                plan.groups.append(.init(id: group.id, label: group.label, members: group.members))
                for id in group.members { plan.cluster[id] = group.id }
            }
            plan.links = snapshot.pairs.map { LayoutLink(first: $0.first, second: $0.second, reason: $0.reason) }
            plan.snapshot = snapshot
            plan.field = field
            plan.legend = "each group is a vibe, and the strings join things that go together. tap one to see why."
            plan.collapsedLegend = "these are the vibes on this board. pinch in or tap one to see what's inside."
        } else {
            let zones: [Zone] = [.now, .tonight, .thisWeekend, .someday, .vibes]
            var byZone: [Zone: [Drop]] = [:]
            for drop in drops {
                let zone = drop.isArriving ? .now : drop.boardZone(now: now)
                byZone[zone, default: []].append(drop)
            }
            for zone in zones {
                let list = (byZone[zone] ?? []).sorted { zone == .vibes ? $0.createdAt > $1.createdAt : $0.sortDate < $1.sortDate }
                guard !list.isEmpty else { continue }
                plan.groups.append(.init(id: zone.rawValue, label: zone.displayName, members: list.map(\.id)))
                plan.links += LayoutLink.trail(list.map(\.id), reason: zone == .vibes ? "saved one after the other." : "this comes next \(zone.displayName).")
                for drop in list { plan.cluster[drop.id] = zone.rawValue }
            }
            plan.legend = "each group is a time, with the soonest in the middle and the dotted line running in order. pinch out to see them all."
            plan.collapsedLegend = "now is at the top. pinch in or tap a group to open it."
        }
        return plan
    }
}

private struct Reading: View {
    let drop: Drop
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        Circle()
            .fill(NightStyle.ink.opacity(0.7))
            .blur(radius: 18)
            .frame(width: size * 2.6, height: size * 2.6)
            .overlay {
                Circle()
                    .strokeBorder(drop.personColor.opacity(0.8), lineWidth: 1.5)
                    .frame(width: size * 1.7, height: size * 1.7)
                    .scaleEffect(breathe ? 1.08 : 0.92)
                    .opacity(breathe ? 0.35 : 0.9)
            }
            .overlay(alignment: .bottom) {
                Text(drop.status == .pending ? "reading what \(drop.authorLabel) shared." : "found where it goes.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NightStyle.secondary)
                    .fixedSize()
                    .offset(y: -size * 0.15)
                    .contentTransition(.opacity)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { breathe = true }
            }
            .allowsHitTesting(false)
            .accessibilityIdentifier("landingDrop")
    }
}
