import SwiftData
import SwiftUI

struct GlassBoard: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @State private var doneOpen = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            GeometryReader { proxy in
                scene(now: timeline.date, size: proxy.size)
            }
        }
        .background { GlassBackdrop() }
        .preferredColorScheme(.dark)
    }

    private func scene(now: Date, size: CGSize) -> some View {
        let layout = GlassLayout(items: Self.items(drops), size: size)
        let vibes = layout.band(.vibes)
        return GlassEffectContainer(spacing: 12) {
            ZStack(alignment: .topLeading) {
                GlassCues.VibesHaze()
                    .frame(width: vibes.width * 1.6, height: vibes.height * 1.3)
                    .position(x: vibes.midX, y: vibes.midY)
                ForEach(links(layout)) { link in
                    GlassCues.Link(from: link.from, to: link.to)
                }
                ForEach(GlassLayout.rows + [.vibes], id: \.self) { zone in
                    label(zone, layout: layout)
                }
                ForEach(drops, id: \.id) { drop in
                    if let placement = layout.placements[drop.id] {
                        GlassDropNode(drop: drop, placement: placement, now: now)
                            .position(placement.center)
                            .zIndex(Double(placement.nearness))
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .overlay(alignment: .top) {
            if drops.isEmpty {
                GlassLine(text: GlassCopy.emptyBoard).padding(.top, 8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            GlassDoneTray(drops: drops.filter { $0.zone == .done }, now: now, isOpen: $doneOpen)
        }
    }

    private func label(_ zone: Zone, layout: GlassLayout) -> some View {
        let point = layout.labelPoint(zone)
        let isNow = zone == .now
        let isVibes = zone == .vibes
        let hidden = layout.hiddenVibes
        let text: String = switch zone {
        case .thisWeekend: "this\nweekend"
        case .vibes: hidden > 0 ? "vibes +\(hidden)" : "vibes"
        default: GlassCopy.zoneLabel(zone)
        }
        return Text(text)
            .font(.system(size: isNow ? 17 : 13, weight: .semibold))
            .tracking(0.2)
            .foregroundStyle(isNow ? GlassTheme.text : GlassTheme.softText)
            .multilineTextAlignment(.leading)
            .fixedSize()
            .frame(width: 88, alignment: isVibes ? .center : .leading)
            .position(x: isVibes ? point.x : point.x + 44, y: point.y)
            .accessibilityAddTraits(.isHeader)
    }

    private func links(_ layout: GlassLayout) -> [GlassJoin] {
        var seen = Set<String>()
        var joins: [GlassJoin] = []
        for drop in drops {
            guard let from = layout.placements[drop.id]?.center else { continue }
            for other in drop.relatedDropIds {
                guard let to = layout.placements[other]?.center else { continue }
                let key = [drop.id.uuidString, other.uuidString].sorted().joined(separator: "-")
                if seen.insert(key).inserted {
                    joins.append(GlassJoin(id: key, from: from, to: to))
                }
            }
        }
        return joins
    }

    private static func items(_ drops: [Drop]) -> [GlassLayout.Item] {
        let rows = drops
            .filter { GlassLayout.rows.contains($0.zone) }
            .sorted { ($0.glassSoonest, $0.createdAt) < ($1.glassSoonest, $1.createdAt) }
        let vibes = drops.filter { $0.zone == .vibes }
        return (rows + vibes).map {
            GlassLayout.Item(id: $0.id, zone: $0.zone, kind: $0.objectKind, manual: $0.glassManualPoint)
        }
    }
}

struct GlassJoin: Identifiable {
    let id: String
    let from: CGPoint
    let to: CGPoint
}

struct GlassDoneTray: View {
    let drops: [Drop]
    let now: Date
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isOpen { shelf }
            HStack(spacing: 8) {
                Text(GlassCopy.zoneLabel(.done))
                    .font(GlassTheme.sentence())
                    .foregroundStyle(GlassTheme.text)
                if !drops.isEmpty {
                    Text("\(drops.count)")
                        .font(GlassTheme.mono())
                        .foregroundStyle(GlassTheme.softText)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: isOpen ? .infinity : nil, alignment: .leading)
        .contentShape(.rect(cornerRadius: 22))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .onTapGesture {
            withAnimation(GlassTheme.morph) { isOpen.toggle() }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("glassDone")
    }

    @ViewBuilder private var shelf: some View {
        if drops.isEmpty {
            Text(GlassCopy.emptyDone)
                .font(GlassTheme.sentence(.regular))
                .foregroundStyle(GlassTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(drops, id: \.id) { drop in
                        let size = GlassLayout.baseSize(for: drop.objectKind)
                        GlassObjectView(drop: drop, now: now, showsText: false)
                            .scaleEffect(0.6)
                            .frame(width: size.width * 0.6, height: size.height * 0.6)
                            .overlay(alignment: .topTrailing) { GlassCues.DoneTick().offset(x: 6, y: -6) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(drop.glassSummary(now: now))
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
            .scrollIndicators(.hidden)
        }
    }
}
