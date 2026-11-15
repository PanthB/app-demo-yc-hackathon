import SwiftUI

struct TagCard: View {
    @Environment(\.mood) private var mood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let drop: Drop
    let frontSize: CGSize
    let onClose: () -> Void
    @State private var angle: Double = 0

    static let width: CGFloat = 300

    var body: some View {
        FlipFaces(angle: angle, startScale: frontSize.width / Self.width, front: front, back: TagBack(drop: drop, onClose: close))
            .onTapGesture(perform: close)
            .onAppear {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.78)) {
                    angle = 180
                }
            }
    }

    private var front: some View {
        PaperObject(drop: drop, size: frontSize)
            .scaleEffect(Self.width / frontSize.width)
            .frame(width: Self.width, height: frontSize.height * Self.width / frontSize.width)
    }

    private func close() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.85)) {
            angle = 0
        } completion: {
            onClose()
        }
    }
}

private struct FlipFaces<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let startScale: CGFloat
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .scaleEffect(startScale + (1 - startScale) * min(1, angle / 180))
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

struct TagBack: View {
    @Environment(\.mood) private var mood
    @Environment(\.openURL) private var openURL
    @Environment(BoardClock.self) private var clock
    @Environment(\.modelContext) private var context
    let drop: Drop
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(mood.ui(22, weight: .semibold))
                .foregroundStyle(mood.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !facts.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(facts, id: \.self) { fact in
                        Text(fact)
                            .font(mood.mono(15))
                            .foregroundStyle(mood.ink)
                    }
                }
            }
            if let line = appLine {
                Text(line)
                    .font(mood.hand(21))
                    .foregroundStyle(mood.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(DropStory.dropped(drop, now: clock.now))
                .font(mood.ui(15))
                .foregroundStyle(mood.quietInk)
                .fixedSize(horizontal: false, vertical: true)
            if let url = drop.url.flatMap(URL.init(string:)) {
                TagLink(text: "open the original") { openURL(url) }
                    .accessibilityIdentifier("openOriginal")
            }
            if drop.zoneSetByUser {
                TagLink(text: "let it move on its own again.") {
                    drop.letAppPlace()
                    BoardSave.save(context, "letting a drop move again")
                    onClose()
                }
                .accessibilityIdentifier("letItMove")
            }
        }
        .padding(EdgeInsets(top: 34, leading: 24, bottom: 26, trailing: 24))
        .frame(width: TagCard.width, alignment: .leading)
        .background(ClippedTopCorners().fill(mood.paper))
        .paperShadow(lifted: true)
        .overlay(alignment: .top) { PinHead().offset(y: 8) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tagBack")
    }

    private var title: String {
        (drop.title ?? drop.rawText ?? drop.linkHost ?? "something you dropped").lowercased()
    }

    private var facts: [String] {
        var lines: [String] = []
        if let type = drop.type, drop.status == .processed { lines.append(type.rawValue) }
        if let dueAt = drop.dueAt {
            lines.append("due \(DropFace.dateTag(dueAt, now: clock.now))")
        } else if let startsAt = drop.startsAt {
            lines.append(DropFace.dateTag(startsAt, now: clock.now))
        } else if let whenLabel = drop.whenLabel {
            lines.append(whenLabel)
        }
        if let artist = drop.artist { lines.append(artist.lowercased()) }
        if let place = drop.placeName { lines.append(place.lowercased()) }
        if let price = drop.price { lines.append(price.lowercased()) }
        return lines
    }

    private var appLine: String? {
        if drop.status == .failed { return "i couldn't read this one, but it's still here." }
        if drop.status == .pending { return "i'm still reading this one. it'll find its spot soon." }
        if drop.zoneUnsure && !drop.zoneSetByUser { return "i couldn't place this one. drag it where it belongs." }
        return nil
    }
}

private struct TagLink: View {
    @Environment(\.mood) private var mood
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(mood.ui(17, weight: .semibold))
                .foregroundStyle(mood.ink)
                .padding(.bottom, 3)
                .background(alignment: .bottom) {
                    Rectangle().fill(mood.person).frame(height: 2)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ClippedTopCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = 14
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

struct UndoSlip: View {
    @Environment(\.mood) private var mood
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(mood.hand(20))
                .foregroundStyle(mood.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(width: 320)
                .frame(minHeight: 56)
                .background(mood.paper)
                .paperShadow()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(-1))
        .accessibilityIdentifier("undoSlip")
    }
}
