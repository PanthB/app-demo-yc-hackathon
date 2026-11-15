import SwiftUI
import UIKit

struct PaperObject: View {
    static let captionHeight: CGFloat = 26 + CorkboardLayout.labelDrop + 4

    let drop: Drop
    let size: CGSize

    var body: some View {
        content
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var content: some View {
        if drop.showsRawThing {
            RawPaper(drop: drop)
        } else {
            switch drop.objectKind {
            case .sticky: StickyNote(drop: drop)
            case .slip: Slip(drop: drop)
            case .stub: Stub(drop: drop)
            case .postcard: Postcard(drop: drop)
            case .record: Record(drop: drop)
            case .polaroid:
                if let image = MediaStore.image(at: drop.thumbnailPath) {
                    Polaroid(drop: drop, image: image)
                } else {
                    RawPaper(drop: drop)
                }
            case .cutout:
                if let image = MediaStore.image(at: drop.cutoutPath ?? drop.thumbnailPath) {
                    Cutout(image: image, title: drop.frontTitle)
                } else {
                    RawPaper(drop: drop)
                }
            }
        }
    }
}

struct CountdownText: View {
    let dueAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text = DropFace.countdown(until: dueAt, now: context.date)
            Text(text)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: text)
        }
    }
}

private struct StickyNote: View {
    @Environment(\.mood) private var mood
    let drop: Drop

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text((drop.rawText ?? drop.title ?? "").lowercased())
                .font(mood.ui(15))
                .foregroundStyle(mood.ink)
                .lineLimit(drop.dueAt == nil ? 5 : 3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let dueAt = drop.dueAt {
                CountdownText(dueAt: dueAt)
                    .font(mood.mono(28, weight: .semibold))
                    .foregroundStyle(mood.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(EdgeInsets(top: 22, leading: 13, bottom: 10, trailing: 11))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            LiftedCorner()
                .fill(mood.butter)
                .overlay(alignment: .top) {
                    Rectangle().fill(mood.shade.opacity(0.06)).frame(height: 16)
                }
                .overlay {
                    LinearGradient(colors: [.white.opacity(0.18), .clear, mood.shade.opacity(0.06)], startPoint: .top, endPoint: .bottomTrailing)
                }
                .clipShape(LiftedCorner())
                .paperShadow()
        }
    }

    private struct LiftedCorner: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 9))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 12, y: rect.maxY), control: CGPoint(x: rect.maxX - 1, y: rect.maxY - 1))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

private struct Polaroid: View {
    @Environment(\.mood) private var mood
    let drop: Drop
    let image: UIImage

    private var isVideo: Bool {
        drop.sourceKind == .video || ["tiktok.com", "instagram.com", "youtube.com", "youtu.be"].contains { drop.linkHost?.hasSuffix($0) == true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if isVideo { PlayBadge().padding(8) }
                }
            Text(drop.frontTitle ?? "")
                .font(mood.ui(15, weight: .medium))
                .foregroundStyle(mood.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .topLeading)
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10))
        .background(mood.paper)
        .paperShadow()
    }
}

private struct PlayBadge: View {
    @Environment(\.mood) private var mood

    var body: some View {
        ZStack {
            Circle().fill(mood.paper.opacity(0.85))
            Triangle()
                .fill(mood.ink)
                .frame(width: 8, height: 9)
                .offset(x: 1)
        }
        .frame(width: 22, height: 22)
        .shadow(color: mood.shade.opacity(0.25), radius: 1, y: 1)
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

private struct Cutout: View {
    @Environment(\.mood) private var mood
    let image: UIImage
    let title: String?

    private static let border: [CGSize] = (0..<16).map { index in
        let angle = Double(index) / 16 * 2 * .pi
        return CGSize(width: cos(angle) * 4, height: sin(angle) * 4)
    }

    var body: some View {
        VStack(spacing: 4) {
            sticker
                .frame(maxHeight: .infinity)
            Text(title ?? "")
                .font(mood.ui(14, weight: .medium))
                .foregroundStyle(mood.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 22)
                .padding(.bottom, CorkboardLayout.labelDrop + 4)
        }
    }

    private var sticker: some View {
        ZStack {
            ForEach(Self.border.indices, id: \.self) { index in
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(mood.stickerWhite)
                    .offset(Self.border[index])
            }
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        .compositingGroup()
        .paperShadow()
    }
}

private struct Record: View {
    @Environment(\.mood) private var mood
    let drop: Drop

    var body: some View {
        ZStack {
            Circle().fill(mood.ink)
            Grooves(seed: drop.id)
                .stroke(mood.paper.opacity(0.14), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            Group {
                if let image = MediaStore.image(at: drop.thumbnailPath) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    mood.butter
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(Circle().stroke(mood.paper.opacity(0.85), lineWidth: 2))
            Circle()
                .fill(mood.board)
                .frame(width: 7, height: 7)
        }
        .paperShadow()
    }

    private struct Grooves: Shape {
        let seed: UUID

        func path(in rect: CGRect) -> Path {
            var random = StableRandom(seed, salt: 53)
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for ring in 0..<4 {
                let radius = rect.width / 2 - 9 - CGFloat(ring) * 7
                let start = random.value(in: 0...360)
                let sweep = random.value(in: 230...300)
                path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + sweep), clockwise: false)
                path.move(to: CGPoint(x: center.x + radius, y: center.y))
            }
            path.move(to: CGPoint(x: center.x - rect.width * 0.28, y: center.y - rect.height * 0.3))
            path.addLine(to: CGPoint(x: center.x - rect.width * 0.2, y: center.y - rect.height * 0.36))
            path.move(to: CGPoint(x: center.x + rect.width * 0.24, y: center.y + rect.height * 0.33))
            path.addLine(to: CGPoint(x: center.x + rect.width * 0.31, y: center.y + rect.height * 0.27))
            return path
        }
    }
}

private struct Slip: View {
    @Environment(\.mood) private var mood
    let drop: Drop

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Scribble(seed: drop.id)
                .stroke(mood.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(height: 28)
            HStack(spacing: 6) {
                Text(drop.frontTitle ?? "voice note")
                    .font(mood.ui(14, weight: .medium))
                    .lineLimit(1)
                if let seconds = drop.mediaDuration {
                    Text(DropFace.duration(seconds))
                        .font(mood.mono(12))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(mood.ink)
        }
        .padding(EdgeInsets(top: 10, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TornPaper(seed: drop.id).fill(mood.paper))
        .paperShadow()
    }

    private struct Scribble: Shape {
        let seed: UUID

        func path(in rect: CGRect) -> Path {
            var random = StableRandom(seed, salt: 13)
            var path = Path()
            let steps = max(Int(rect.width / 3), 1)
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            for step in 1...steps {
                let x = rect.minX + CGFloat(step) / CGFloat(steps) * rect.width
                let envelope = sin(Double(step) / Double(steps) * .pi) * 0.8 + 0.2
                let amplitude = random.value(in: 0.15...1) * envelope * Double(rect.height) / 2
                path.addLine(to: CGPoint(x: x, y: rect.midY + CGFloat(step % 2 == 0 ? amplitude : -amplitude)))
            }
            return path
        }
    }
}

private struct TornPaper: Shape {
    let seed: UUID

    func path(in rect: CGRect) -> Path {
        var random = StableRandom(seed, salt: 23)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 3))
        var x = rect.maxX
        while x > rect.minX {
            x = max(rect.minX, x - CGFloat(random.value(in: 4...9)))
            path.addLine(to: CGPoint(x: x, y: rect.maxY - CGFloat(random.value(in: 0...3.5))))
        }
        path.closeSubpath()
        return path
    }
}

private struct Stub: View {
    @Environment(\.mood) private var mood
    @Environment(BoardClock.self) private var clock
    let drop: Drop

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                mood.person
                Circle().fill(mood.board).frame(width: 8, height: 8)
            }
            .frame(width: 24)
            DottedTear()
                .stroke(mood.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 5]))
                .frame(width: 2)
                .padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(drop.frontTag(now: clock.now))
                    .font(mood.mono(20, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(mood.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let title = drop.frontTitle {
                    Text(title)
                        .font(mood.ui(15, weight: .medium))
                        .foregroundStyle(mood.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(mood.paper)
        .clipShape(PerforatedTrailingEdge())
        .paperShadow()
    }

    private struct DottedTear: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }
}

private struct PerforatedTrailingEdge: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 2.5
        let spacing: CGFloat = 8
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        var y = rect.minY + spacing / 2
        while y + radius < rect.maxY {
            path.addLine(to: CGPoint(x: rect.maxX, y: y - radius))
            path.addArc(center: CGPoint(x: rect.maxX, y: y), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            y += spacing
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Postcard: View {
    @Environment(\.mood) private var mood
    let drop: Drop

    var body: some View {
        let image = MediaStore.image(at: drop.thumbnailPath)
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if let image {
                    Color.clear
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }
                        .clipped()
                        .frame(width: (proxy.size.width - 18) * 0.4)
                    Rectangle()
                        .fill(mood.ink.opacity(0.16))
                        .frame(width: 1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(drop.frontTitle ?? drop.linkHost ?? "")
                        .font(mood.ui(15, weight: .medium))
                        .foregroundStyle(mood.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .padding(.top, 4)
                    Spacer(minLength: 6)
                    VStack(spacing: 10) {
                        ForEach(0..<3) { _ in
                            Rectangle().fill(mood.ink.opacity(0.16)).frame(height: 1)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.leading, image == nil ? 6 : 0)
            }
            .padding(9)
        }
        .background(mood.paper)
        .compositingGroup()
        .paperShadow()
    }
}

struct RawPaper: View {
    @Environment(\.mood) private var mood
    let drop: Drop

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = MediaStore.image(at: drop.thumbnailPath ?? drop.cutoutPath) {
                Color.clear
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipped()
            }
            if let text = drop.rawText, !text.isEmpty {
                Text(text.lowercased())
                    .font(mood.ui(15))
                    .foregroundStyle(mood.ink)
                    .lineLimit(3)
            }
            if let host = drop.linkHost {
                Text(host)
                    .font(mood.mono(12))
                    .tracking(0.3)
                    .foregroundStyle(mood.quietInk)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(mood.paper)
        .compositingGroup()
        .paperShadow()
    }
}
