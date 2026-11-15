import SwiftUI

struct OrbitGeometry {
    struct Member: Sendable {
        let id: UUID
        let ring: Int
        let angle: Double
    }

    let radii: [CGFloat]
    private(set) var points: [UUID: CGPoint] = [:]

    init(members: [Member], radii: [CGFloat], node: CGFloat) {
        self.radii = radii
        for (ring, radius) in radii.enumerated() {
            let onRing = members.filter { $0.ring == ring }
            guard !onRing.isEmpty, radius > 0 else { continue }
            let wanted = Double(node + 6) / Double(radius)
            let crowded = 2 * Double.pi / Double(onRing.count) < wanted
            let sorted = onRing.sorted { Self.sweep($0.angle) < Self.sweep($1.angle) }
            let spread = Self.spread(sorted.map { Self.sweep($0.angle) }, gap: crowded ? wanted / 1.8 : wanted)
            for (index, member) in sorted.enumerated() {
                let lane: CGFloat = crowded ? (index.isMultiple(of: 2) ? -node * 0.34 : node * 0.34) : 0
                let angle = spread[index] - Double.pi / 2
                points[member.id] = CGPoint(x: (radius + lane) * cos(angle), y: (radius + lane) * sin(angle))
            }
        }
    }

    static func sweep(_ angle: Double) -> Double {
        let turn = 2 * Double.pi
        let value = (angle + Double.pi / 2).truncatingRemainder(dividingBy: turn)
        return value < 0 ? value + turn : value
    }

    static func spread(_ desired: [Double], gap: Double) -> [Double] {
        guard desired.count > 1 else { return desired }
        let turn = 2 * Double.pi
        let gap = min(gap, turn / Double(desired.count))
        var placed = desired
        for index in 1..<placed.count {
            placed[index] = max(placed[index], placed[index - 1] + gap)
        }
        if placed[placed.count - 1] - placed[0] > turn - gap {
            placed = placed.indices.map { placed[0] + Double($0) * turn / Double(desired.count) }
        }
        let shift = zip(placed, desired).map { $0 - $1 }.reduce(0, +) / Double(desired.count)
        return placed.map { $0 - shift }
    }

    static func clock(_ date: Date, calendar: Calendar = .current) -> Double {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double((parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0))
        return -Double.pi / 2 + seconds / 86400 * 2 * Double.pi
    }
}

struct OrbitView: View {
    let drops: [Drop]
    let namespace: Namespace.ID
    let open: (Drop) -> Void

    @Environment(BoardClock.self) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: UUID?
    @State private var appeared = false

    private static let node: CGFloat = 36

    var body: some View {
        let now = clock.now
        let shown = drops.filter { $0.boardZone(now: now) != .done }
        let plan = Self.plan(shown, now: now)
        let byId = Dictionary(drops.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        GeometryReader { proxy in
            let radius = min(proxy.size.width / 2 - 30, (proxy.size.height - 170) / 2)
            let center = CGPoint(x: proxy.size.width / 2, y: max(radius + 30, (proxy.size.height - 120) / 2))
            let inner = max(radius * 0.3, 50)
            let outer = radius - (plan.isShared ? 30 : 26)
            let count = plan.rings.count
            let radii = (0..<count).map { inner + (outer - inner) * CGFloat($0) / CGFloat(max(count - 1, 1)) }
            let geometry = OrbitGeometry(members: plan.members, radii: radii, node: Self.node)
            let related = Set(plan.links.filter { $0.touches(selected) }.map { $0.other(than: selected ?? UUID()) })

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(LayoutMotion.select(reduceMotion)) { selected = nil } }

                Canvas { context, _ in
                    for ring in radii {
                        let circle = Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
                        context.stroke(circle, with: .color(.white.opacity(0.1)), lineWidth: 1)
                    }
                    if plan.isShared {
                        for sector in plan.sectors {
                            var line = Path()
                            line.move(to: Self.point(center, inner - 26, sector.start))
                            line.addLine(to: Self.point(center, radius, sector.start))
                            context.stroke(line, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        }
                    } else {
                        for hour in 0..<24 {
                            let angle = -Double.pi / 2 + Double(hour) / 24 * 2 * Double.pi
                            var tick = Path()
                            tick.move(to: Self.point(center, radius - (hour % 6 == 0 ? 10 : 5), angle))
                            tick.addLine(to: Self.point(center, radius, angle))
                            context.stroke(tick, with: .color(.white.opacity(hour % 6 == 0 ? 0.45 : 0.18)), lineWidth: 1)
                        }
                    }
                    if let selected, let from = geometry.points[selected] {
                        for link in plan.links where link.touches(selected) {
                            guard let to = geometry.points[link.other(than: selected)] else { continue }
                            var chord = Path()
                            let a = CGPoint(x: center.x + from.x, y: center.y + from.y)
                            let b = CGPoint(x: center.x + to.x, y: center.y + to.y)
                            chord.move(to: a)
                            chord.addQuadCurve(to: b, control: CGPoint(x: center.x + (from.x + to.x) * 0.2, y: center.y + (from.y + to.y) * 0.2))
                            context.stroke(chord, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        }
                    }
                }
                .allowsHitTesting(false)

                if !plan.isShared {
                    TimelineView(.everyMinute) { context in
                        Canvas { canvas, _ in
                            let angle = OrbitGeometry.clock(context.date)
                            var hand = Path()
                            hand.move(to: Self.point(center, 40, angle))
                            hand.addLine(to: Self.point(center, radius - 2, angle))
                            canvas.stroke(hand, with: .style(.tint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            let tip = Self.point(center, radius - 2, angle)
                            canvas.fill(Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y - 4, width: 8, height: 8)), with: .style(.tint))
                        }
                    }
                    .allowsHitTesting(false)
                    ForEach(Array(["midnight", "6am", "noon", "6pm"].enumerated()), id: \.offset) { index, word in
                        Text(word)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NightStyle.tertiary)
                            .fixedSize()
                            .position(Self.point(center, radius + 14, -Double.pi / 2 + Double(index) * Double.pi / 2))
                    }
                }

                ForEach(Array(plan.rings.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NightStyle.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NightStyle.ink.opacity(0.85), in: .capsule)
                        .fixedSize()
                        .position(x: center.x, y: center.y - radii[index])
                        .opacity(appeared ? 1 : 0)
                }

                if plan.isShared {
                    ForEach(plan.sectors) { sector in
                        NightAvatar(name: sector.name, colorName: sector.color, personId: sector.id, size: 26)
                            .position(Self.point(center, radius + 12, sector.middle))
                    }
                }

                hub(now: now, isShared: plan.isShared)
                    .position(center)

                ForEach(shown) { drop in
                    if let point = geometry.points[drop.id] {
                        let ring = plan.members.first { $0.id == drop.id }?.ring ?? 0
                        node(drop, related: related)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.3)
                            .opacity(appeared ? 1 : 0)
                            .position(appeared || reduceMotion ? CGPoint(x: center.x + point.x, y: center.y + point.y) : center)
                            .animation(LayoutMotion.arrive(reduceMotion, delay: Double(ring) * 0.09 + Double(abs(point.x)) * 0.0008), value: appeared)
                            .zIndex(selected == drop.id ? 2 : 1)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .overlay(alignment: .bottom) {
                Group {
                    if let selected, let drop = byId[selected] {
                        LayoutFocusPanel(drop: drop, lines: lines(for: drop, links: plan.links, byId: byId)) {
                            open(drop)
                        } close: {
                            withAnimation(LayoutMotion.select(reduceMotion)) { self.selected = nil }
                        }
                        .padding(.horizontal, 12)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else {
                        LayoutLegend(text: plan.legend)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }
                }
                .animation(LayoutMotion.settle(reduceMotion), value: selected)
            }
            .onAppear { appeared = true }
            .sensoryFeedback(.selection, trigger: selected)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("orbit")
        }
    }

    private func hub(now: Date, isShared: Bool) -> some View {
        VStack(spacing: 2) {
            if isShared {
                Text("you").font(.headline.weight(.bold))
            } else {
                TimelineView(.everyMinute) { context in
                    Text(context.date.formatted(.dateTime.hour().minute()).lowercased())
                        .font(.headline.weight(.heavy))
                        .monospacedDigit()
                }
                Text("you're here").font(.caption2).foregroundStyle(NightStyle.tertiary)
            }
        }
        .frame(width: 68, height: 68)
        .background(NightStyle.surface, in: .circle)
        .overlay { Circle().strokeBorder(NightStyle.hairline, lineWidth: 1) }
        .onTapGesture { withAnimation(LayoutMotion.select(reduceMotion)) { selected = nil } }
        .accessibilityElement(children: .combine)
    }

    private func node(_ drop: Drop, related: Set<UUID>) -> some View {
        let dim = selected != nil && selected != drop.id && !related.contains(drop.id)
        return Button {
            if selected == drop.id {
                open(drop)
            } else {
                withAnimation(LayoutMotion.select(reduceMotion)) { selected = drop.id }
            }
        } label: {
            LayoutBadge(drop: drop, size: Self.node * (drop.isPinned ? 1.1 : 1))
                .scaleEffect(selected == drop.id ? 1.35 : 1)
                .animation(LayoutMotion.select(reduceMotion), value: selected)
        }
        .buttonStyle(NightPressStyle())
        .matchedTransitionSource(id: drop.id, in: namespace)
        .contextMenu { NightDropMenu(drop: drop) }
        .opacity(dim ? 0.3 : 1)
        .accessibilityLabel(drop.spokenLabel(now: clock.now, beside: .plain))
        .accessibilityIdentifier("layoutNode")
    }

    private func lines(for drop: Drop, links: [LayoutLink], byId: [UUID: Drop]) -> [String] {
        links.filter { $0.touches(drop.id) }.prefix(2).compactMap { link in
            guard let other = byId[link.other(than: drop.id)] else { return nil }
            return "goes with \(other.layoutTitle). \(link.reason)"
        }
    }

    static func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    struct Sector: Identifiable {
        let id: String
        let name: String
        let color: String?
        let start: Double
        let end: Double
        var middle: Double { (start + end) / 2 }
    }

    struct Plan {
        var isShared = false
        var rings: [String] = []
        var members: [OrbitGeometry.Member] = []
        var sectors: [Sector] = []
        var links: [LayoutLink] = []
        var legend = ""
    }

    static func plan(_ drops: [Drop], now: Date, calendar: Calendar = .current) -> Plan {
        var plan = Plan()
        let people = drops.sorted { $0.createdAt < $1.createdAt }.reduce(into: [Drop]()) { list, drop in
            if !list.contains(where: { $0.authorId == drop.authorId }) { list.append(drop) }
        }
        plan.isShared = people.count > 1
        if plan.isShared {
            let turn = 2 * Double.pi
            let width = turn / Double(people.count)
            for (index, person) in people.enumerated() {
                let start = -Double.pi / 2 + Double(index) * width
                plan.sectors.append(Sector(id: person.authorId, name: person.authorLabel, color: person.authorColor, start: start, end: start + width))
            }
            func ring(_ drop: Drop) -> Int {
                let age = now.timeIntervalSince(drop.createdAt)
                return age < 86400 ? 0 : (age < 7 * 86400 ? 1 : 2)
            }
            let names = ["today", "this week", "earlier"]
            let deepest = drops.map(ring).max() ?? 0
            plan.rings = Array(names.prefix(max(deepest + 1, 2)))
            for sector in plan.sectors {
                let theirs = drops.filter { $0.authorId == sector.id }
                for band in 0..<plan.rings.count {
                    let onBand = theirs.filter { ring($0) == band }.sorted { $0.createdAt > $1.createdAt }
                    let margin = (sector.end - sector.start) * 0.12
                    let usable = sector.end - sector.start - margin * 2
                    for (index, drop) in onBand.enumerated() {
                        let angle = sector.start + margin + usable * (Double(index) + 0.5) / Double(onBand.count)
                        plan.members.append(.init(id: drop.id, ring: band, angle: angle))
                    }
                }
            }
            plan.links = LayoutLink.strings(drops)
            plan.legend = "each friend has a slice, and the closer to the middle, the newer. tap one to see what it goes with."
        } else {
            plan.rings = ["now", "tonight", "this weekend", "someday"]
            var later: [Drop] = []
            for drop in drops {
                let zone = drop.isArriving ? .now : drop.boardZone(now: now)
                switch zone {
                case .now: plan.members.append(.init(id: drop.id, ring: 0, angle: OrbitGeometry.clock(drop.isArriving ? now : drop.sortDate, calendar: calendar)))
                case .tonight: plan.members.append(.init(id: drop.id, ring: 1, angle: OrbitGeometry.clock(drop.sortDate, calendar: calendar)))
                case .thisWeekend: plan.members.append(.init(id: drop.id, ring: 2, angle: OrbitGeometry.clock(drop.sortDate, calendar: calendar)))
                default: later.append(drop)
                }
            }
            let ordered = later.sorted { $0.createdAt > $1.createdAt }
            for (index, drop) in ordered.enumerated() {
                plan.members.append(.init(id: drop.id, ring: 3, angle: -Double.pi / 2 + (Double(index) + 0.5) / Double(ordered.count) * 2 * Double.pi))
            }
            plan.legend = "it reads like a clock. the hand is now, and each ring out is further away, from now to someday."
        }
        return plan
    }
}
