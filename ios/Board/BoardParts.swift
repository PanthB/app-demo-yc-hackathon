import SwiftUI

struct PinHead: View {
    @Environment(\.mood) private var mood
    var ringed = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [mood.person.mix(with: .white, by: 0.45), mood.person, mood.personDeep],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: 10
                ))
                .overlay(Circle().stroke(mood.personDeep, lineWidth: 1))
                .frame(width: 16, height: 16)
                .contactShadow(mood)
            if ringed {
                Circle()
                    .stroke(mood.ink, lineWidth: 2)
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityHidden(true)
    }
}

struct TapeStrip: View {
    @Environment(\.mood) private var mood
    let seed: UUID

    var body: some View {
        var random = StableRandom(seed, salt: 31)
        let turn = random.value(in: 4...10) * (random.value(in: 0...1) < 0.5 ? -1 : 1)
        return TornEnds(seed: seed)
            .fill(mood.paper.opacity(0.75))
            .overlay(TornEnds(seed: seed).stroke(mood.shade.opacity(0.1), lineWidth: 0.5))
            .frame(width: 46, height: 18)
            .contactShadow(mood)
            .rotationEffect(.degrees(turn))
            .accessibilityHidden(true)
    }
}

struct TornEnds: Shape {
    let seed: UUID

    func path(in rect: CGRect) -> Path {
        var random = StableRandom(seed, salt: 41)
        var path = Path()
        let teeth = 6
        let step = rect.height / CGFloat(teeth)
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        for index in 1...teeth {
            let x = rect.maxX - CGFloat(random.value(in: 0...2.5))
            path.addLine(to: CGPoint(x: x, y: rect.minY + step * CGFloat(index)))
        }
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        for index in stride(from: teeth - 1, through: 0, by: -1) {
            let x = rect.minX + CGFloat(random.value(in: 0...2.5))
            path.addLine(to: CGPoint(x: x, y: rect.minY + step * CGFloat(index)))
        }
        path.closeSubpath()
        return path
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
            .fixedSize()
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
    let zone: Zone

    var body: some View {
        Text(zone.displayName)
            .font(mood.hand(zone == .now ? 40 : 28))
            .fontWeight(.bold)
            .foregroundStyle(mood.ink)
            .fixedSize()
            .background(alignment: .bottom) {
                if zone == .now {
                    MarkerStroke()
                        .stroke(mood.person, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(height: 6)
                        .offset(y: -2)
                }
            }
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
        Text(text)
            .font(mood.hand(20))
            .fontWeight(.bold)
            .foregroundStyle(mood.ink)
            .fixedSize()
    }
}

struct EnvelopeBack: View {
    @Environment(\.mood) private var mood

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(mood.lilac.mix(with: mood.paper, by: 0.35).mix(with: mood.shade, by: 0.06))
            FlapShape()
                .fill(mood.lilac.mix(with: mood.paper, by: 0.45))
                .frame(height: 26)
                .offset(y: -24)
        }
        .paperShadow()
        .accessibilityHidden(true)
    }

    private struct FlapShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - 6, y: rect.minY + 2))
            path.addQuadCurve(to: CGPoint(x: rect.midX + 6, y: rect.minY + 2), control: CGPoint(x: rect.midX, y: rect.minY - 1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

struct EnvelopeFront: View {
    @Environment(\.mood) private var mood

    var body: some View {
        PocketShape(dip: 20)
            .fill(mood.lilac.mix(with: mood.paper, by: 0.3))
            .overlay(PocketShape(dip: 20).stroke(mood.lilac.mix(with: mood.ink, by: 0.45).opacity(0.5), lineWidth: 0.8))
            .shadow(color: mood.shade.opacity(0.16), radius: 2, y: -1)
            .accessibilityHidden(true)
    }
}

struct DonePocket: View {
    @Environment(\.mood) private var mood

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(mood.paper)
            Rectangle().fill(mood.mint).frame(height: 9)
            TickMark()
                .stroke(mood.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 12)
                .offset(y: 22)
        }
        .paperShadow()
        .accessibilityHidden(true)
    }
}

struct TickMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

struct PocketShape: Shape {
    let dip: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + dip))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
