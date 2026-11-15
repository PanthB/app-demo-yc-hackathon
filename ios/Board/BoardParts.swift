import SwiftUI

struct PinHead: View {
    @Environment(\.mood) private var mood

    var body: some View {
        ZStack {
            Image("Kit/pin-shadow")
                .foregroundStyle(mood.shade.opacity(0.35))
                .offset(y: 1.5)
            Image("Kit/pin-head")
                .foregroundStyle(mood.person)
            Image("Kit/pin-head-shade")
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

struct TapeStrip: View {
    @Environment(\.mood) private var mood
    let seed: UUID

    var body: some View {
        var random = StableRandom(seed, salt: 31)
        let turn = random.value(in: 3...7) * (random.value(in: 0...1) < 0.5 ? -1 : 1)
        return Image("Kit/tape-strip")
            .foregroundStyle(mood.paper.opacity(0.75))
            .contactShadow(mood)
            .rotationEffect(.degrees(turn))
            .accessibilityHidden(true)
    }
}

struct StringLine: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        let distance = hypot(to.x - from.x, to.y - from.y)
        let control = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 + distance * 0.24)
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        return path
    }
}

private struct TagPaper: ViewModifier {
    @Environment(\.mood) private var mood

    func body(content: Content) -> some View {
        content
            .font(mood.mono(12, weight: .medium))
            .tracking(0.3)
            .monospacedDigit()
            .foregroundStyle(mood.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(mood.paper, in: RoundedRectangle(cornerRadius: 3))
            .contactShadow(mood)
    }
}

extension View {
    func tagPaper() -> some View {
        modifier(TagPaper())
    }
}

struct ZoneLabel: View {
    @Environment(\.mood) private var mood
    let title: String
    let count: Int
    let isNow: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(mood.handLabel(title))
                .font(mood.hand(isNow ? 40 : 28))
                .fontWeight(.bold)
                .foregroundStyle(mood.ink)
                .background(alignment: .bottom) {
                    if isNow {
                        MarkerStroke()
                            .stroke(mood.person, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(height: 6)
                            .offset(y: -2)
                    }
                }
            Text("\(count)")
                .font(mood.mono(12, weight: .medium))
                .foregroundStyle(mood.ink)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "\(title), 1 thing" : "\(title), \(count) things")
        .accessibilityAddTraits(.isHeader)
    }

    private struct MarkerStroke: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY + 1))
            path.addCurve(
                to: CGPoint(x: rect.maxX - 1, y: rect.midY - 1),
                control1: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY),
                control2: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY)
            )
            return path
        }
    }
}

struct CornerLabel: View {
    @Environment(\.mood) private var mood
    let text: String

    var body: some View {
        Text(mood.handLabel(text))
            .font(mood.hand(20))
            .fontWeight(.bold)
            .foregroundStyle(mood.ink)
            .fixedSize()
    }
}

struct DonePocket: View {
    var body: some View {
        ZStack {
            Image("Kit/done-pocket-back")
            Image("Kit/done-pocket-front")
        }
        .paperShadow()
        .accessibilityHidden(true)
    }
}
