import SwiftData
import SwiftUI

struct BoardWeb: View {
    let boardId: String
    var focus: String? = nil

    @Query(sort: \Drop.createdAt, order: .reverse) private var allDrops: [Drop]
    @Environment(BoardClock.self) private var clock
    @Environment(BoardsStore.self) private var boards
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = SuggestionsModel()
    @State private var picked: FeedSuggestion?
    @State private var note: String?

    private var suggestions: [String: [FeedSuggestion]] {
        var byGroup: [String: [FeedSuggestion]] = [:]
        for group in model.groups ?? [] {
            byGroup[group.clusterId] = group.suggestions.filter { !model.hidden.contains($0.id) }
        }
        return byGroup
    }

    var body: some View {
        let drops = allDrops.filter { drop in
            (drop.boardId.isEmpty ? BoardKeys.personalBoard : drop.boardId) == boardId && drop.clusterId != nil && !drop.isArriving && drop.boardZone(now: clock.now) != .done
        }
        GeometryReader { proxy in
            let web = BoardWebLayout(drops: drops, suggestions: suggestions, width: proxy.size.width)
            ScrollViewReader { reader in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        Canvas { context, _ in
                            for link in web.links {
                                var path = Path()
                                path.move(to: link.from)
                                path.addQuadCurve(to: link.to, control: link.control)
                                context.stroke(path, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                            }
                        }
                        .frame(width: proxy.size.width, height: web.height)
                        .allowsHitTesting(false)
                        ForEach(web.groups) { group in
                            label(group)
                                .frame(width: proxy.size.width - NightStyle.margin * 2, alignment: .leading)
                                .position(x: proxy.size.width / 2, y: group.top + 24)
                            Color.clear.frame(width: 1, height: 1).position(x: proxy.size.width / 2, y: group.center.y).id(group.id)
                        }
                        ForEach(web.satellites) { spot in
                            if let suggestion = spot.suggestion {
                                Button { picked = suggestion } label: {
                                    BoardWebSuggestion(suggestion: suggestion, side: spot.side)
                                }
                                .buttonStyle(.plain)
                                .position(spot.point)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                                .accessibilityIdentifier("webSuggestion")
                            }
                        }
                        ForEach(web.nodes) { spot in
                            if let drop = spot.drop {
                                Button {
                                    if let link = drop.url.flatMap({ URL(string: $0) }) { openURL(link) }
                                } label: {
                                    BoardWebDrop(drop: drop, side: spot.side, now: clock.now)
                                }
                                .buttonStyle(.plain)
                                .position(spot.point)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                                .accessibilityIdentifier("webDrop")
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: web.height, alignment: .topLeading)
                    .animation(NightStyle.motion(reduceMotion), value: web.signature)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard let focus else { return }
                    reader.scrollTo(focus, anchor: .center)
                }
            }
        }
        .background { NightBackdrop() }
        .preferredColorScheme(.dark)
        .navigationTitle(boards.boards.first { $0.boardId == boardId }?.name ?? "the whole board")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let note {
                Text(note)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(NightStyle.motion(reduceMotion), value: note)
        .task(id: note) {
            guard note != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            note = nil
        }
        .confirmationDialog(picked?.title ?? "", isPresented: Binding(get: { picked != nil }, set: { if !$0 { picked = nil } }), titleVisibility: .visible, presenting: picked) { suggestion in
            Button("save to board") {
                model.save(suggestion, as: boards.personId)
                note = "saved to \(boards.boards.first { $0.boardId == boardId }?.name ?? "the board")."
            }
            if let link = suggestion.link {
                Button("open it") { openURL(link) }
            }
            Button("dismiss", role: .destructive) { model.dismiss(suggestion) }
        }
        .task(id: boardId) { model.follow(boardId: boardId, personId: boards.personId) }
        .onDisappear { model.stop() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("boardWeb")
    }

    private func label(_ group: BoardWebLayout.Group) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.label)
                .font(NightStyle.heading)
                .foregroundStyle(.white)
                .lineLimit(1)
            if let together = group.together {
                Text(together)
                    .font(NightStyle.body)
                    .foregroundStyle(NightStyle.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("webGroup-\(group.id)")
    }
}

struct BoardWebStop: Hashable, Identifiable {
    let focus: String?

    var id: String { "web-" + (focus ?? "all") }
}

struct BoardWebLayout {
    struct Group: Identifiable {
        let id: String
        let label: String
        let together: String?
        let top: CGFloat
        let center: CGPoint
    }

    struct Spot: Identifiable {
        let id: String
        let point: CGPoint
        let side: CGFloat
        var drop: Drop?
        var suggestion: FeedSuggestion?
    }

    struct Link {
        let from: CGPoint
        let to: CGPoint
        let control: CGPoint
    }

    var groups: [Group] = []
    var nodes: [Spot] = []
    var satellites: [Spot] = []
    var links: [Link] = []
    var height: CGFloat = 0
    var signature: [String] = []

    static let perGroup = 7
    static let ring: CGFloat = 92
    static let header: CGFloat = 64
    static let block: CGFloat = 300

    init(drops: [Drop], suggestions: [String: [FeedSuggestion]], width: CGFloat) {
        var order: [String] = []
        var members: [String: [Drop]] = [:]
        for drop in drops {
            guard let id = drop.clusterId else { continue }
            if members[id] == nil { order.append(id) }
            members[id, default: []].append(drop)
        }
        var place: [UUID: CGPoint] = [:]
        var top: CGFloat = 8
        for (row, id) in order.enumerated() {
            let shown = Array((members[id] ?? []).prefix(Self.perGroup))
            guard let newest = shown.first else { continue }
            let center = CGPoint(x: width / 2 + (row.isMultiple(of: 2) ? -18 : 18), y: top + Self.header + Self.block / 2 - 16)
            let people = Self.people(members[id] ?? [])
            groups.append(Group(id: id, label: newest.clusterLabel ?? "a vibe", together: people.count > 1 ? Self.together(people) : nil, top: top, center: center))
            for (index, drop) in shown.enumerated() {
                let point: CGPoint
                let side: CGFloat
                if index == 0 {
                    point = center
                    side = 96
                } else {
                    let angle = -Double.pi / 2 + Double(index - 1) / Double(max(shown.count - 1, 1)) * 2 * .pi
                    point = CGPoint(x: center.x + cos(angle) * Self.ring, y: center.y + sin(angle) * Self.ring)
                    side = index < 3 ? 62 : 54
                }
                place[drop.id] = point
                nodes.append(Spot(id: drop.id.uuidString, point: point, side: side, drop: drop))
            }
            let extra = Array((suggestions[id] ?? []).prefix(3))
            for (index, suggestion) in extra.enumerated() {
                let x = row.isMultiple(of: 2) ? center.x + Self.ring + 64 : center.x - Self.ring - 64
                let y = center.y - 56 + CGFloat(index) * 56
                satellites.append(Spot(id: suggestion.id, point: CGPoint(x: min(max(x, 30), width - 30), y: y), side: 42, suggestion: suggestion))
            }
            top += Self.header + Self.block
        }
        height = top + 24
        signature = nodes.map(\.id) + satellites.map(\.id)
        links = Self.links(drops: drops, place: place, width: width)
    }

    static func people(_ drops: [Drop]) -> [String] {
        var seen: [String] = []
        for drop in drops {
            let name = drop.authorLabel.lowercased()
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    static func together(_ people: [String]) -> String {
        let names = people.count > 3 ? Array(people.prefix(2)) + ["\(people.count - 2) more"] : people
        let list = names.count == 2 ? names.joined(separator: " and ") : names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        return "\(list) are into this."
    }

    static func links(drops: [Drop], place: [UUID: CGPoint], width: CGFloat) -> [Link] {
        let shown = drops.filter { place[$0.id] != nil }
        var used: Set<UUID> = []
        var links: [Link] = []
        for drop in shown where !used.contains(drop.id) {
            let vibes = Set(drop.vibes.map { $0.lowercased() })
            guard !vibes.isEmpty else { continue }
            let best = shown
                .filter { $0.clusterId != drop.clusterId && $0.authorLabel != drop.authorLabel && !used.contains($0.id) }
                .map { ($0, vibes.intersection($0.vibes.map { $0.lowercased() }).count) }
                .filter { $0.1 > 0 }
                .max { $0.1 < $1.1 }
            guard let (other, _) = best, let a = place[drop.id], let b = place[other.id] else { continue }
            used.insert(drop.id)
            used.insert(other.id)
            let left = (a.x + b.x) / 2 < width / 2
            let control = CGPoint(x: left ? -width * 0.12 : width * 1.12, y: (a.y + b.y) / 2)
            links.append(Link(from: a, to: b, control: control))
            if links.count == 4 { break }
        }
        return links
    }
}

private struct BoardWebDrop: View {
    let drop: Drop
    let side: CGFloat
    let now: Date

    var body: some View {
        let corner = side * 0.26
        face(corner: corner)
            .padding(3)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: corner + 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner + 3, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
            }
            .contentShape(.rect)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\((drop.title ?? "a drop").lowercased()), from \(drop.authorLabel.lowercased())")
            .accessibilityAddTraits(.isLink)
    }
}

extension BoardWebDrop {
    @ViewBuilder
    func face(corner: CGFloat) -> some View {
        switch drop.previewFace(now: now) {
        case .image, .cutout:
            DropThumbnail(face: drop.previewFace(now: now), kind: drop.kind, seed: drop.id, side: side, radius: corner)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: drop.kind.symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NightStyle.secondary)
                Text((drop.title ?? drop.kind.word).lowercased())
                    .font(.system(size: max(9, side * 0.13), weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(side > 80 ? 4 : 3)
                    .minimumScaleFactor(0.8)
            }
            .padding(side > 80 ? 10 : 6)
            .frame(width: side, height: side, alignment: .topLeading)
            .background(NightStyle.surface.opacity(0.7), in: .rect(cornerRadius: corner, style: .continuous))
        }
    }
}

private struct BoardWebSuggestion: View {
    let suggestion: FeedSuggestion
    let side: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            if let url = suggestion.thumbnailUrl.flatMap({ URL(string: $0) }) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    symbol
                }
                .clipShape(.circle)
                .padding(3)
            } else {
                symbol
            }
        }
        .frame(width: side, height: side)
        .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1) }
        .contentShape(.circle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("suggestion: \(suggestion.title.lowercased())")
        .accessibilityAddTraits(.isButton)
    }

    private var symbol: some View {
        Image(systemName: suggestion.pill.symbol)
            .font(.system(size: side * 0.36, weight: NightStyle.symbolWeight))
            .foregroundStyle(.white.opacity(0.85))
    }
}
