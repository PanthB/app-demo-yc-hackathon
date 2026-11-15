import SwiftData
import SwiftUI

struct PaperBoardRoot: View {
    @Query(sort: \Drop.createdAt) private var drops: [Drop]
    @Environment(BoardClock.self) private var clock
    @AppStorage(Mood.handwritingKey) private var handwriting = true

    private static var debugAnchor: UnitPoint? {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "BoardDebugAnchor") == "bottom" { return .bottom }
        #endif
        return nil
    }

    var body: some View {
        var mood = Mood.sunny
        mood.handwriting = handwriting
        return GeometryReader { proxy in
            let home = DeviceIdentity.boardId
            let sections = DropSection.build(
                drops.filter { $0.boardId == home || $0.boardId.isEmpty },
                filter: .everyone,
                me: DeviceIdentity.personId,
                now: clock.now
            )
            let layout = CorkboardLayout(sections: sections, width: proxy.size.width, minHeight: proxy.size.height)
            ScrollView(.vertical) {
                Corkboard(layout: layout, width: proxy.size.width)
                    .background { CorkSurface().padding(.vertical, -240) }
                    .environment(\.colorScheme, .light)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(Self.debugAnchor)
            .accessibilityIdentifier("paperBoard")
        }
        .background(mood.board.ignoresSafeArea())
        .environment(\.mood, mood)
        .animation(mood.move, value: clock.now)
    }
}

private struct Corkboard: View {
    @Environment(\.mood) private var mood
    let layout: CorkboardLayout
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.headers) { header in
                ZoneLabel(title: header.title, count: header.count, isNow: header.isNow)
                    .accessibilityIdentifier("section-\(header.id)")
                    .accessibilitySortPriority(-Double(header.order))
                    .offset(x: CorkboardLayout.margin, y: header.top)
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

            ForEach(layout.items) { item in
                BoardItem(item: item)
                    .contextMenu { DropMenu(drop: item.drop) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spokenName(for: item))
                    .accessibilityIdentifier("drop-\(item.drop.showsRawThing ? "raw" : item.drop.objectKind.rawValue)")
                    .accessibilitySortPriority(-Double(item.order))
                    .rotationEffect(.degrees(item.tilt))
                    .position(item.center)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            if let pocket = layout.pocket {
                DonePocket()
                    .rotationEffect(.degrees(-1))
                    .position(x: pocket.midX, y: pocket.midY)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    CornerLabel(text: Zone.done.displayName)
                    Text("\(layout.doneCount)")
                        .font(mood.mono(12, weight: .medium))
                        .foregroundStyle(mood.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(layout.doneCount == 1 ? "done, 1 thing" : "done, \(layout.doneCount) things")
                .accessibilityIdentifier("donePocket")
                .accessibilitySortPriority(-10_000)
                .offset(x: pocket.maxX + 8, y: pocket.minY + 12)
            }

            if let center = layout.emptyNoteCenter {
                EmptyBoardNote()
                    .frame(width: min(280, width - 2 * CorkboardLayout.margin))
                    .position(center)
            }
        }
        .frame(width: width, height: layout.height, alignment: .topLeading)
        .animation(mood.land, value: layout.items.map(\.id))
    }

    private func spokenName(for item: CorkboardLayout.Item) -> String {
        let drop = item.drop
        let name = drop.frontTitle ?? drop.rawText?.lowercased() ?? drop.linkHost
        let when = drop.dueAt.map { DropFace.countdown(until: $0, now: .now) } ?? drop.tag(now: .now)
        return [drop.kind.word, name, drop.authorLabel, when].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

private struct BoardItem: View {
    @Environment(\.mood) private var mood
    let item: CorkboardLayout.Item

    var body: some View {
        let avatarInset: CGFloat = item.drop.objectKind == .record && !item.drop.showsRawThing ? 18 : 7
        PaperObject(drop: item.drop, size: item.size)
            .overlay(alignment: .topTrailing) {
                PersonAvatar(drop: item.drop)
                    .overlay(Circle().stroke(mood.paper, lineWidth: 1.5))
                    .contactShadow(mood)
                    .offset(x: 9 - avatarInset, y: avatarInset - 9)
            }
            .overlay(alignment: .top) {
                switch item.fastener {
                case .pin: PinHead().offset(y: -7)
                case .tape: TapeStrip(seed: item.id).offset(y: -4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ObjectLabel(drop: item.drop)
                    .frame(width: item.labelWidth, alignment: .trailing)
                    .offset(x: -8, y: CorkboardLayout.labelDrop)
            }
    }
}

private struct ObjectLabel: View {
    @Environment(BoardClock.self) private var clock
    let drop: Drop

    var body: some View {
        let kind = drop.kind
        let facesTime = drop.objectKind == .stub || (drop.objectKind == .sticky && drop.dueAt != nil)
        let time = facesTime && !drop.showsRawThing ? nil : drop.tag(now: clock.now)
        HStack(spacing: 4) {
            Image(systemName: kind.symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(kind.word)
            if let time {
                Text("·")
                if let dueAt = drop.dueAt {
                    CountdownText(dueAt: dueAt)
                } else {
                    Text(time)
                }
            }
        }
        .tagPaper()
    }
}

private struct EmptyBoardNote: View {
    @Environment(\.mood) private var mood
    private static let tapeSeed = UUID(uuid: (0xE4, 0x97, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    var body: some View {
        Text("nothing here yet. share anything from any app and it'll show up.")
            .font(mood.hand(24))
            .foregroundStyle(mood.ink)
            .multilineTextAlignment(.center)
            .padding(EdgeInsets(top: 24, leading: 18, bottom: 18, trailing: 18))
            .background(mood.paper)
            .compositingGroup()
            .paperShadow()
            .overlay(alignment: .top) { TapeStrip(seed: Self.tapeSeed).offset(y: -6) }
            .rotationEffect(.degrees(-1))
            .accessibilityIdentifier("emptyBoardNote")
    }
}
