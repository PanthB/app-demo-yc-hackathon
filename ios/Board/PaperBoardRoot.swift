import os
import SwiftData
import SwiftUI

struct DragState: Equatable {
    let id: UUID
    var translation: CGSize
    var lifted: Bool
}

struct PaperBoardRoot: View {
    @Query(sort: \Drop.createdAt) private var drops: [Drop]
    @Environment(BoardClock.self) private var clock
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var seen: [UUID: Zone]? = SeenBoard.load()
    @State private var flipped: Flipped?
    @State private var undo: UndoNote?
    @State private var drag: DragState?
    @Namespace private var flipSpace
    private let mood = Mood.sunny

    private struct Flipped: Equatable {
        let id: UUID
        let size: CGSize
    }

    private struct UndoNote: Equatable {
        let id = UUID()
        let dropId: UUID
        let text: String
    }

    private static var debugAnchor: UnitPoint? {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "BoardDebugAnchor") == "bottom" { return .bottom }
        #endif
        return nil
    }

    var body: some View {
        GeometryReader { proxy in
            let contents = BoardContents(drops, now: clock.now, seen: seen ?? [:])
            let layout = CorkboardLayout(contents: contents, width: proxy.size.width, minHeight: proxy.size.height, now: clock.now)
            ScrollView(.vertical) {
                Corkboard(
                    contents: contents,
                    layout: layout,
                    width: proxy.size.width,
                    flippedId: flipped?.id,
                    flipSpace: flipSpace,
                    drag: $drag,
                    onFlip: { item in
                        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : mood.move) {
                            flipped = Flipped(id: item.id, size: item.size)
                        }
                    },
                    onMove: { item, zone, center in
                        move(item, to: zone, center: center, layout: layout, size: proxy.size)
                    }
                )
                .background { CorkSurface().padding(.vertical, -240) }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(drag?.lifted == true)
            .defaultScrollAnchor(Self.debugAnchor)
            .accessibilityIdentifier("paperBoard")
        }
        .blur(radius: flipped == nil ? 0 : 6)
        .overlay { flipOverlay }
        .overlay(alignment: .bottom) { undoOverlay }
        .background(mood.board.ignoresSafeArea())
        .environment(\.mood, mood)
        .preferredColorScheme(.light)
        .sensoryFeedback(.impact(weight: .light), trigger: flipped)
        .task { await flyFromLastSeen() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { rememberBoard() }
        }
    }

    @ViewBuilder
    private var flipOverlay: some View {
        if let flipped, let drop = drops.first(where: { $0.id == flipped.id }) {
            ZStack {
                mood.shade.opacity(0.35).ignoresSafeArea()
                TagCard(drop: drop, frontSize: flipped.size) {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : mood.move) { self.flipped = nil }
                }
                .matchedGeometryEffect(id: flipped.id, in: flipSpace, properties: .position)
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var undoOverlay: some View {
        if let undo {
            UndoSlip(text: undo.text) { putBack(undo) }
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undo.id) {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, self.undo?.id == undo.id else { return }
                    withAnimation(mood.lift) { self.undo = nil }
                }
        }
    }

    private func move(_ item: CorkboardLayout.Item, to zone: Zone, center: CGPoint?, layout: CorkboardLayout, size: CGSize) {
        let drop = item.drop
        let spot = center.flatMap { zone == .vibes || zone == .done ? nil : layout.manualPlacement(center: $0, zone: zone, width: size.width) }
        drop.moveByUser(to: zone, x: spot?.x, y: spot?.y)
        BoardSave.save(context, "moving a drop by hand")
        Logger.app.info("moved a drop to \(zone.rawValue, privacy: .public) by hand")

        let after = CorkboardLayout(contents: BoardContents(drops, now: clock.now), width: size.width, minHeight: size.height, now: clock.now)
        if let center, let landed = after.items.first(where: { $0.id == drop.id }) {
            drag = DragState(id: drop.id, translation: CGSize(width: center.x - landed.center.x, height: center.y - landed.center.y), lifted: true)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(mood.lift) {
                    drag = DragState(id: drop.id, translation: .zero, lifted: false)
                } completion: {
                    if drag?.id == drop.id, drag?.lifted == false { drag = nil }
                }
            }
        } else {
            withAnimation(mood.lift) { drag = nil }
        }
        withAnimation(mood.lift) {
            undo = UndoNote(dropId: drop.id, text: UndoWords.sentence(for: zone))
        }
    }

    private func putBack(_ note: UndoNote) {
        if let drop = drops.first(where: { $0.id == note.dropId }) {
            drop.undoMove()
            BoardSave.save(context, "putting a drop back")
            Logger.app.info("put a moved drop back")
        }
        withAnimation(mood.lift) { undo = nil }
    }

    private func flyFromLastSeen() async {
        guard seen != nil else { return }
        try? await Task.sleep(for: .milliseconds(450))
        seen = nil
        rememberBoard()
    }

    private func rememberBoard() {
        SeenBoard.save(BoardContents(drops, now: clock.now).zones)
    }
}

private struct Corkboard: View {
    @Environment(\.mood) private var mood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let contents: BoardContents
    let layout: CorkboardLayout
    let width: CGFloat
    let flippedId: UUID?
    let flipSpace: Namespace.ID
    @Binding var drag: DragState?
    let onFlip: (CorkboardLayout.Item) -> Void
    let onMove: (CorkboardLayout.Item, Zone, CGPoint?) -> Void
    @State private var hoverZone: Zone?

    static let space = "corkboard"

    var body: some View {
        let threaded = layout.threadedIds
        let doneCount = contents.drops(in: .done).count
        let vibesCount = contents.drops(in: .vibes).count
        ZStack(alignment: .topLeading) {
            ForEach(layout.labels) { label in
                ZoneLabel(zone: label.zone, highlighted: drag?.lifted == true && hoverZone == label.zone)
                    .accessibilitySortPriority(-Double(label.order))
                    .offset(x: label.origin.x, y: label.origin.y)
            }

            DonePocket()
                .frame(width: layout.pocket.width, height: layout.pocket.height)
                .scaleEffect(hoverZone == .done && drag?.lifted == true ? 1.08 : 1)
                .rotationEffect(.degrees(-2))
                .position(x: layout.pocket.midX, y: layout.pocket.midY)
            PinHead()
                .position(x: layout.pocket.midX, y: layout.pocket.minY + 4)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CornerLabel(text: "done")
                if doneCount > 0 {
                    Text("\(doneCount)")
                        .font(mood.mono(12, weight: .medium))
                        .foregroundStyle(mood.ink)
                        .contentTransition(.numericText())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(doneCount == 1 ? "done, 1 thing" : "done, \(doneCount) things")
            .accessibilityIdentifier("donePocket")
            .accessibilitySortPriority(-10_000)
            .offset(x: layout.pocket.maxX + 8, y: layout.pocket.minY + 12)

            EnvelopeBack()
                .frame(width: layout.envelope.width, height: layout.envelope.height)
                .position(x: layout.envelope.midX, y: layout.envelope.midY)
            ZStack(alignment: .topLeading) {
                ForEach(layout.vibes) { item in
                    placed(item)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(width: width, height: layout.height)
            .mask { VibesWindow(envelope: layout.envelope) }
            EnvelopeFront()
                .frame(width: layout.envelope.width, height: layout.envelope.height)
                .position(x: layout.envelope.midX, y: layout.envelope.midY)
            PinHead()
                .position(x: layout.envelope.midX, y: layout.envelope.minY + 24)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CornerLabel(text: "vibes")
                if vibesCount > layout.vibes.count {
                    Text("+\(vibesCount - layout.vibes.count)")
                        .font(mood.mono(12, weight: .medium))
                        .foregroundStyle(mood.ink)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(vibesCount == 1 ? "vibes, 1 thing" : "vibes, \(vibesCount) things")
            .accessibilityIdentifier("vibesEnvelope")
            .accessibilitySortPriority(-10_001)
            .frame(width: layout.envelope.minX - 8, alignment: .trailing)
            .offset(y: layout.envelope.midY - 4)

            ForEach(layout.items.sorted { $0.center.y < $1.center.y }) { item in
                placed(item)
                    .transition(reduceMotion ? .opacity : .modifier(active: LandingPose(lift: 1), identity: LandingPose(lift: 0)))
            }

            ForEach(layout.threads) { thread in
                ZStack {
                    StringLine(from: thread.from, to: thread.to)
                        .stroke(mood.person, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    StringLine(from: thread.from, to: thread.to)
                        .stroke(mood.personDeep, style: StrokeStyle(lineWidth: 2.5, lineCap: .butt, dash: [1.5, 9]))
                }
                .contactShadow(mood)
                .opacity(drag == nil ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            ForEach(layout.items + layout.vibes) { item in
                fastener(for: item, threaded: threaded.contains(item.id))
                    .offset(offset(for: item))
                    .opacity(flippedId == item.id ? 0 : 1)
                    .animation(motion(for: item), value: item.center)
                    .zIndex(drag?.id == item.id ? 11 : 0)
                    .allowsHitTesting(false)
            }

            ForEach(layout.items.filter { $0.tag != nil }) { item in
                tag(for: item)
                    .offset(offset(for: item))
                    .opacity(flippedId == item.id ? 0 : 1)
                    .animation(motion(for: item), value: item.center)
                    .zIndex(drag?.id == item.id ? 11 : 0)
                    .allowsHitTesting(false)
            }

            if let center = layout.emptyNoteCenter {
                EmptyBoardNote()
                    .frame(width: min(280, width - CorkboardLayout.objectLeading - CorkboardLayout.trailing))
                    .position(center)
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: layout.height, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : mood.land, value: layout.items.map(\.id))
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : mood.move, value: layout.labels.map(\.origin.y))
        .animation(mood.move, value: layout.envelope)
        .sensoryFeedback(.selection, trigger: hoverZone) { _, new in new != nil }
        .sensoryFeedback(.impact(weight: .medium), trigger: drag?.lifted) { old, new in old != new && new != nil }
    }

    private func offset(for item: CorkboardLayout.Item) -> CGSize {
        drag?.id == item.id ? drag?.translation ?? .zero : .zero
    }

    private func motion(for item: CorkboardLayout.Item) -> Animation? {
        if drag?.id == item.id { return nil }
        if reduceMotion { return .easeInOut(duration: 0.25) }
        return mood.move.delay(Double(item.order) * 0.03)
    }

    private func placed(_ item: CorkboardLayout.Item) -> some View {
        PlacedObject(
            item: item,
            layout: layout,
            flipped: flippedId == item.id,
            flipSpace: flipSpace,
            drag: $drag,
            hoverZone: $hoverZone,
            motion: motion(for: item),
            onFlip: { onFlip(item) },
            onMove: { zone, center in onMove(item, zone, center) }
        )
        .zIndex(drag?.id == item.id ? 10 : 0)
    }

    @ViewBuilder
    private func fastener(for item: CorkboardLayout.Item, threaded: Bool) -> some View {
        switch item.fastener {
        case .tape:
            TapeStrip(seed: item.id)
                .rotationEffect(.degrees(item.tilt))
                .position(item.pinPoint)
        case .ringedPin:
            PinHead(ringed: true).position(item.pinPoint)
        case .pin:
            PinHead().position(item.pinPoint)
        case .none:
            if threaded {
                PinHead().position(item.pinPoint)
            }
        }
    }

    private func tag(for item: CorkboardLayout.Item) -> some View {
        var random = StableRandom(item.id, salt: 61)
        let turn = random.value(in: 2...4) * (item.tilt < 0 ? 1 : -1)
        return Color.clear
            .frame(width: 1, height: 1)
            .overlay(alignment: .topTrailing) {
                if let dueAt = item.drop.dueAt {
                    CountdownText(dueAt: dueAt).tagPaper()
                } else if let text = item.tag {
                    Text(text).tagPaper()
                }
            }
            .rotationEffect(.degrees(item.tilt + turn))
            .position(item.tagCorner)
            .accessibilityHidden(true)
    }
}

private struct PlacedObject: View {
    @Environment(\.mood) private var mood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: CorkboardLayout.Item
    let layout: CorkboardLayout
    let flipped: Bool
    let flipSpace: Namespace.ID
    @Binding var drag: DragState?
    @Binding var hoverZone: Zone?
    let motion: Animation?
    let onFlip: () -> Void
    let onMove: (Zone, CGPoint?) -> Void

    var body: some View {
        let current = drag?.id == item.id ? drag : nil
        let lifted = current?.lifted == true
        let travel = max(-6, min(6, Double(current?.translation.width ?? 0) / 30))
        Group {
            if flipped {
                Color.clear.frame(width: item.size.width, height: item.size.height)
            } else {
                PaperObject(drop: item.drop, size: item.size)
                    .matchedGeometryEffect(id: item.id, in: flipSpace, properties: .position)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenName)
        .accessibilityIdentifier("drop-\(item.drop.showsRawThing ? "raw" : item.drop.objectKind.rawValue)")
        .accessibilitySortPriority(-Double(item.order))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("flips it over to see what was saved.")
        .accessibilityAction { onFlip() }
        .accessibilityActions {
            ForEach(Zone.allCases.filter { $0 != item.zone }, id: \.self) { zone in
                Button("move to \(zone.displayName)") { onMove(zone, nil) }
            }
        }
        .onTapGesture(perform: onFlip)
        .gesture(dragGesture)
        .shadow(color: mood.shade.opacity(lifted ? 0.22 : 0), radius: 18, y: 14)
        .scaleEffect(item.scale * (lifted ? 1.05 : 1))
        .rotationEffect(.degrees(lifted && !reduceMotion ? item.tilt * 0.3 + travel : item.tilt))
        .animation(mood.lift, value: lifted)
        .position(item.center)
        .offset(current?.translation ?? .zero)
        .animation(motion, value: item.center)
    }

    private var spokenName: String {
        let drop = item.drop
        let kind = drop.showsRawThing ? "new drop" : drop.objectKind.rawValue
        let name = drop.frontTitle ?? drop.rawText?.lowercased() ?? drop.linkHost
        let place = item.zone?.displayName ?? "just arrived"
        let when = drop.dueAt.map { DropFace.countdown(until: $0, now: .now) } ?? item.tag
        return [kind, name, place, when].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Corkboard.space)))
            .onChanged { value in
                guard case .second(true, let moved) = value else { return }
                drag = DragState(id: item.id, translation: moved?.translation ?? .zero, lifted: true)
                hoverZone = layout.zone(at: moved?.location ?? item.center)
            }
            .onEnded { value in
                hoverZone = nil
                guard case .second(true, let moved?) = value, moved.translation != .zero else {
                    withAnimation(mood.lift) { drag = nil }
                    return
                }
                let center = CGPoint(x: item.center.x + moved.translation.width, y: item.center.y + moved.translation.height)
                onMove(layout.zone(at: moved.location), center)
            }
    }
}

private struct LandingPose: ViewModifier {
    let lift: Double

    func body(content: Content) -> some View {
        content
            .offset(y: -280 * lift)
            .scaleEffect(1 + 0.08 * lift)
            .rotationEffect(.degrees(-8 * lift))
    }
}

private struct VibesWindow: Shape {
    let envelope: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: envelope.minY + 10 - rect.minY))
        path.addRect(envelope)
        return path
    }
}

private struct EmptyBoardNote: View {
    @Environment(\.mood) private var mood

    var body: some View {
        Text("nothing pinned yet. share anything here from any app and it'll show up.")
            .font(mood.hand(24))
            .foregroundStyle(mood.ink)
            .multilineTextAlignment(.center)
            .padding(EdgeInsets(top: 24, leading: 18, bottom: 18, trailing: 18))
            .background(mood.paper)
            .paperShadow()
            .overlay(alignment: .top) { PinHead().offset(y: -2) }
            .rotationEffect(.degrees(-1.5))
            .accessibilityIdentifier("emptyBoardNote")
    }
}
