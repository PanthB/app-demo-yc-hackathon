import MapKit
import SwiftUI

struct MapAnchors {
    struct Item {
        let id: UUID
        let hasPlace: Bool
        let cluster: String?
        let createdAt: Date
        let neighbors: [(id: UUID, reason: String)]
    }

    private(set) var satellites: [UUID: [UUID]] = [:]
    private(set) var reasons: [UUID: String] = [:]
    private(set) var loose: [UUID] = []

    init(_ items: [Item], clusterLabels: [String: String] = [:]) {
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let places = items.filter(\.hasPlace)
        for item in items where !item.hasPlace {
            if let direct = item.neighbors.first(where: { byId[$0.id]?.hasPlace == true }) {
                attach(item.id, to: direct.id, reason: direct.reason)
                continue
            }
            if let cluster = item.cluster {
                let mates = places.filter { $0.cluster == cluster }
                if let reached = Self.nearest(from: item, among: Set(mates.map(\.id)), byId: byId) {
                    attach(item.id, to: reached.place, reason: reached.reason)
                    continue
                }
                if let newest = mates.max(by: { $0.createdAt < $1.createdAt }) {
                    attach(item.id, to: newest.id, reason: clusterLabels[cluster].map { "same vibe, \($0)." } ?? "same vibe.")
                    continue
                }
            }
            loose.append(item.id)
        }
    }

    private mutating func attach(_ id: UUID, to place: UUID, reason: String) {
        satellites[place, default: []].append(id)
        reasons[id] = reason
    }

    private static func nearest(from start: Item, among targets: Set<UUID>, byId: [UUID: Item]) -> (place: UUID, reason: String)? {
        var seen: Set<UUID> = [start.id]
        var queue: [(id: UUID, reason: String)] = start.neighbors.map { ($0.id, $0.reason) }
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard seen.insert(current.id).inserted, let item = byId[current.id] else { continue }
            if targets.contains(current.id) { return (current.id, current.reason) }
            queue += item.neighbors.map { ($0.id, current.reason) }
        }
        return nil
    }
}

struct NightMapView: View {
    let drops: [Drop]
    let namespace: Namespace.ID
    let open: (Drop) -> Void

    @Environment(BoardClock.self) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: UUID?
    @State private var framedFor: [UUID] = []

    var body: some View {
        let now = clock.now
        let shown = drops.filter { $0.boardZone(now: now) != .done }
        let byId = Dictionary(drops.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let anchors = Self.anchors(shown)
        let places = shown.filter(\.hasPlace)

        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            ForEach(places) { place in
                Annotation(place.placeName ?? place.layoutTitle, coordinate: CLLocationCoordinate2D(latitude: place.latitude ?? 0, longitude: place.longitude ?? 0), anchor: .center) {
                    PlaceStar(
                        place: place,
                        named: !Self.crowded(place, among: places) || selected == place.id,
                        satellites: (anchors.satellites[place.id] ?? []).compactMap { byId[$0] },
                        selected: selected
                    ) { drop in
                        tap(drop, at: place)
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) {
            LinearGradient(colors: [NightStyle.ink, NightStyle.ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 40)
                .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if let selected, let drop = byId[selected] {
                    LayoutFocusPanel(drop: drop, lines: lines(for: drop, anchors: anchors, byId: byId), namespace: namespace) {
                        open(drop)
                    } close: {
                        withAnimation(LayoutMotion.select(reduceMotion)) { self.selected = nil }
                    }
                    .padding(.horizontal, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else {
                    tray(anchors.loose.compactMap { byId[$0] })
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 4)
            .animation(LayoutMotion.settle(reduceMotion), value: selected)
        }
        .onAppear { frame(places) }
        .onChange(of: places.map(\.id)) { _, _ in frame(places) }
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .contain)
            .accessibilityIdentifier("nightMap")
    }

    private func tray(_ loose: [Drop]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LayoutLegend(text: loose.isEmpty
                ? "places glow where they are, in the color of whoever saved them. songs and clips sit beside the place they go with."
                : "places glow where they are. songs and clips sit beside the place they go with, and these don't have one yet.")
            if !loose.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(loose) { drop in
                            Button {
                                withAnimation(LayoutMotion.select(reduceMotion)) { selected = drop.id }
                            } label: {
                                LayoutBadge(drop: drop, size: 46)
                            }
                            .buttonStyle(NightPressStyle())
                            .contextMenu { NightDropMenu(drop: drop) }
                            .accessibilityLabel(drop.spokenLabel(now: clock.now, beside: .plain))
                            .accessibilityIdentifier("layoutNode")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.top, 12)
        .background {
            LinearGradient(colors: [NightStyle.ink.opacity(0), NightStyle.ink.opacity(0.9)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func tap(_ drop: Drop, at place: Drop) {
        if selected == drop.id {
            open(drop)
            return
        }
        withAnimation(LayoutMotion.select(reduceMotion)) { selected = drop.id }
        guard let latitude = place.latitude, let longitude = place.longitude else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.8)) {
            camera = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: latitude - 0.0025, longitude: longitude), distance: 5200))
        }
    }

    private func frame(_ places: [Drop]) {
        let ids = places.map(\.id)
        guard ids != framedFor, !places.isEmpty else { return }
        framedFor = ids
        let latitudes = places.compactMap(\.latitude)
        let longitudes = places.compactMap(\.longitude)
        guard let south = latitudes.min(), let north = latitudes.max(), let west = longitudes.min(), let east = longitudes.max() else { return }
        let span = MKCoordinateSpan(latitudeDelta: max((north - south) * 1.9, 0.02), longitudeDelta: max((east - west) * 1.5, 0.02))
        camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (north + south) / 2 - span.latitudeDelta * 0.12, longitude: (east + west) / 2), span: span))
    }

    private func lines(for drop: Drop, anchors: MapAnchors, byId: [UUID: Drop]) -> [String] {
        if let reason = anchors.reasons[drop.id],
           let place = anchors.satellites.first(where: { $0.value.contains(drop.id) }).flatMap({ byId[$0.key] }) {
            return ["sits by \(place.placeName ?? place.layoutTitle). \(reason)"]
        }
        let around = anchors.satellites[drop.id]?.compactMap { byId[$0]?.layoutTitle } ?? []
        guard !around.isEmpty else { return [] }
        return ["\(around.joined(separator: ", ")) \(around.count == 1 ? "goes" : "go") with this place."]
    }

    static func crowded(_ place: Drop, among places: [Drop]) -> Bool {
        places.contains { other in
            other.id != place.id && abs((other.latitude ?? 0) - (place.latitude ?? 0)) < 0.006 && abs((other.longitude ?? 0) - (place.longitude ?? 0)) < 0.008
        }
    }

    static func anchors(_ drops: [Drop]) -> MapAnchors {
        let labels = Dictionary(drops.compactMap { drop in drop.clusterId.map { ($0, drop.clusterLabel ?? "") } }, uniquingKeysWith: { first, _ in first })
        return MapAnchors(drops.map { drop in
            MapAnchors.Item(
                id: drop.id,
                hasPlace: drop.hasPlace,
                cluster: drop.clusterId,
                createdAt: drop.createdAt,
                neighbors: drop.neighbors.compactMap { neighbor in UUID(uuidString: neighbor.clientId).map { ($0, neighbor.reason) } }
            )
        }, clusterLabels: labels)
    }
}

private struct PlaceStar: View {
    let place: Drop
    let named: Bool
    let satellites: [Drop]
    let selected: UUID?
    let tap: (Drop) -> Void

    @Environment(BoardClock.self) private var clock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    static let orbit: CGFloat = 60
    static let side: CGFloat = 180

    var body: some View {
        let active = selected == place.id || satellites.contains { $0.id == selected }
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [place.personColor.opacity(active ? 0.6 : 0.38), place.personColor.opacity(0)], center: .center, startRadius: 4, endRadius: 58))
                .frame(width: 116, height: 116)
                .scaleEffect(lit || reduceMotion ? 1 : 0.4)
                .allowsHitTesting(false)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for index in satellites.indices {
                    let end = Self.spot(index, in: size)
                    var tether = Path()
                    tether.move(to: center)
                    tether.addLine(to: end)
                    context.stroke(tether, with: .color(.white.opacity(active ? 0.6 : 0.3)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }
            .frame(width: Self.side, height: Self.side)
            .allowsHitTesting(false)
            ForEach(Array(satellites.enumerated()), id: \.element.id) { index, drop in
                button(drop, size: 34)
                    .position(Self.spot(index, in: CGSize(width: Self.side, height: Self.side)))
            }
            VStack(spacing: 4) {
                button(place, size: 50)
                Text(place.placeName ?? place.layoutTitle)
                    .opacity(named ? 1 : 0)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 3)
                    .fixedSize()
            }
            .offset(y: 10)
        }
        .frame(width: Self.side, height: Self.side)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.9, bounce: 0.2)) { lit = true }
        }
    }

    private func button(_ drop: Drop, size: CGFloat) -> some View {
        Button {
            tap(drop)
        } label: {
            LayoutBadge(drop: drop, size: size)
                .scaleEffect(selected == drop.id ? 1.25 : 1)
                .animation(LayoutMotion.select(reduceMotion), value: selected)
        }
        .buttonStyle(NightPressStyle())
        .contextMenu { NightDropMenu(drop: drop) }
        .accessibilityLabel(drop.spokenLabel(now: clock.now, beside: .plain))
        .accessibilityIdentifier("layoutNode")
    }

    static func spot(_ index: Int, in size: CGSize) -> CGPoint {
        let angle = (-60 + Double(index) * 55) * Double.pi / 180
        let reach = orbit + CGFloat(index / 6) * 30
        return CGPoint(x: size.width / 2 + reach * cos(angle), y: size.height / 2 + reach * sin(angle))
    }
}
