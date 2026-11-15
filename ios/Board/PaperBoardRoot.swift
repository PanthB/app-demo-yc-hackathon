import SwiftData
import SwiftUI

struct PaperBoardRoot: View {
    @Query(sort: \Drop.createdAt) private var drops: [Drop]
    @Environment(BoardClock.self) private var clock
    private let mood = Mood.sunny

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let contents = BoardContents(drops, now: clock.now)
            let layout = CorkboardLayout(
                contents: contents,
                width: proxy.size.width,
                minHeight: proxy.size.height - insets.top - insets.bottom,
                now: clock.now
            )
            ScrollView(.vertical) {
                Corkboard(contents: contents, layout: layout, width: proxy.size.width)
                    .padding(.top, insets.top)
                    .padding(.bottom, insets.bottom)
                    .background(alignment: .top) { CorkSurface() }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("paperBoard")
        }
        .ignoresSafeArea(.container)
        .background(mood.board)
        .environment(\.mood, mood)
        .preferredColorScheme(.light)
        .animation(mood.move, value: clock.now)
    }
}

private struct Corkboard: View {
    @Environment(\.mood) private var mood
    let contents: BoardContents
    let layout: CorkboardLayout
    let width: CGFloat

    var body: some View {
        let threaded = layout.threadedIds
        let doneCount = contents.drops(in: .done).count
        let vibesCount = contents.drops(in: .vibes).count
        ZStack(alignment: .topLeading) {
            ForEach(layout.labels) { label in
                ZoneLabel(zone: label.zone)
                    .accessibilitySortPriority(priority(label.order))
                    .offset(x: label.origin.x, y: label.origin.y)
            }

            DonePocket()
                .frame(width: layout.pocket.width, height: layout.pocket.height)
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
            }

            ForEach(layout.threads) { thread in
                ZStack {
                    StringLine(from: thread.from, to: thread.to)
                        .stroke(mood.person, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    StringLine(from: thread.from, to: thread.to)
                        .stroke(mood.personDeep, style: StrokeStyle(lineWidth: 2.5, lineCap: .butt, dash: [1.5, 9]))
                }
                .contactShadow(mood)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            ForEach(layout.items + layout.vibes) { item in
                fastener(for: item, threaded: threaded.contains(item.id))
            }

            ForEach(layout.items.filter { $0.tag != nil }) { item in
                tag(for: item)
            }

            if let center = layout.emptyNoteCenter {
                EmptyBoardNote()
                    .frame(width: min(280, width - CorkboardLayout.objectLeading - CorkboardLayout.trailing))
                    .position(center)
            }
        }
        .frame(width: width, height: layout.height, alignment: .topLeading)
    }

    private func priority(_ order: Int) -> Double {
        -Double(order)
    }

    private func placed(_ item: CorkboardLayout.Item) -> some View {
        PaperObject(drop: item.drop, size: item.size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenName(for: item))
            .accessibilityIdentifier("drop-\(item.drop.showsRawThing ? "raw" : item.drop.objectKind.rawValue)")
            .accessibilitySortPriority(priority(item.order))
            .scaleEffect(item.scale)
            .rotationEffect(.degrees(item.tilt))
            .position(item.center)
    }

    private func spokenName(for item: CorkboardLayout.Item) -> String {
        let drop = item.drop
        let kind = drop.showsRawThing ? "new drop" : drop.objectKind.rawValue
        let name = drop.frontTitle ?? drop.rawText?.lowercased() ?? drop.linkHost
        let place = item.zone?.displayName ?? "just arrived"
        let when = drop.dueAt.map { DropFace.countdown(until: $0, now: .now) } ?? item.tag
        return [kind, name, place, when].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
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
