import SwiftUI

struct GlassObjectView: View {
    let drop: Drop
    var now: Date = .now
    var showsText = true

    var body: some View {
        let size = GlassLayout.baseSize(for: drop.objectKind)
        face.frame(width: size.width, height: size.height)
    }

    @ViewBuilder private var face: some View {
        if drop.status != .processed {
            GlassPlainObject(drop: drop, showsText: showsText)
        } else {
            switch drop.objectKind {
            case .cutout: GlassCutout(drop: drop)
            case .polaroid: GlassPolaroid(drop: drop, showsText: showsText)
            case .record: GlassRecord(drop: drop)
            case .slip: GlassSlip()
            case .sticky: GlassSticky(drop: drop, now: now, showsText: showsText)
            case .stub: GlassStub(drop: drop, now: now, showsText: showsText)
            case .postcard: GlassPostcard(drop: drop, showsText: showsText)
            }
        }
    }
}

struct GlassPlainObject: View {
    let drop: Drop
    let showsText: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        ZStack {
            shape.fill(GlassKit.paper)
            if let image = GlassMedia.image(at: drop.thumbnailPath ?? drop.mediaPaths.first) {
                Color.clear
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipShape(shape)
            } else if showsText {
                Text(GlassCopy.rawSummary(text: drop.rawText, url: drop.url))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(GlassKit.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(10)
            }
        }
    }
}

struct GlassCutout: View {
    let drop: Drop

    var body: some View {
        if let image = GlassMedia.image(at: drop.cutoutPath) {
            GlassSticker { Image(uiImage: image).resizable().scaledToFit() }
        } else if let art = sampleArt {
            GlassSticker { art }
        } else {
            GlassPolaroid(drop: drop, showsText: false)
        }
    }

    private var sampleArt: AnyView? {
        #if DEBUG
        return GlassSampleArt.view(for: drop.cutoutPath)
        #else
        return nil
        #endif
    }
}

struct GlassSticker<Art: View>: View {
    @ViewBuilder var art: Art

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { step in
                Color.white
                    .opacity(0.92)
                    .mask { art }
                    .offset(Self.rim(step))
            }
            art
        }
        .compositingGroup()
    }

    private static func rim(_ step: Int) -> CGSize {
        let angle = CGFloat(step) * .pi / 4
        return CGSize(width: cos(angle) * 2, height: sin(angle) * 2)
    }
}

struct GlassPolaroid: View {
    let drop: Drop
    let showsText: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: 88, height: 88)
                .overlay { photo }
                .clipped()
                .offset(x: 8, y: 8)
            if let frame = GlassKit.image("polaroid-frame") {
                frame
            } else {
                GlassWindowFrame(window: CGRect(x: 8, y: 8, width: 88, height: 88))
                    .fill(GlassKit.paper, style: FillStyle(eoFill: true))
            }
            if drop.sourceKind == .video {
                GlassPlayBadge().offset(x: 66, y: 66)
            }
            if showsText, let caption = GlassCopy.shortTitle(drop.title) {
                Text(caption)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(GlassKit.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 88, height: 24, alignment: .leading)
                    .offset(x: 8, y: 98)
            }
        }
        .frame(width: 104, height: 124, alignment: .topLeading)
    }

    @ViewBuilder private var photo: some View {
        if let image = GlassMedia.image(at: drop.thumbnailPath ?? drop.mediaPaths.first) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            GlassStandInPhoto(id: drop.id)
        }
    }
}

struct GlassRecord: View {
    let drop: Drop

    var body: some View {
        ZStack {
            if let disc = GlassKit.image("record-disc") {
                disc
            } else {
                Circle().fill(GlassKit.ink)
                ForEach(0..<4, id: \.self) { groove in
                    Circle()
                        .strokeBorder(GlassKit.paper.opacity(0.14), lineWidth: 1)
                        .padding(CGFloat(6 + groove * 6))
                }
            }
            if let art = GlassMedia.image(at: drop.thumbnailPath) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 49, height: 49)
                    .clipShape(Circle())
            } else if let blank = GlassKit.image("record-label-blank") {
                blank
            } else {
                Circle().fill(GlassKit.butter).frame(width: 50, height: 50)
            }
            if let ring = GlassKit.image("record-label-ring") {
                ring
            } else {
                Circle().strokeBorder(GlassKit.paper, lineWidth: 4).frame(width: 56, height: 56)
                Circle().fill(GlassKit.paper).frame(width: 12, height: 12)
            }
        }
        .frame(width: 120, height: 120)
    }
}

struct GlassSlip: View {
    var body: some View {
        ZStack {
            if let slip = GlassKit.image("slip") {
                slip.renderingMode(.template).foregroundStyle(GlassKit.paper)
            } else {
                GlassTornSlip().fill(GlassKit.paper)
            }
            GlassWaveform()
                .stroke(GlassKit.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 120, height: 32)
        }
        .frame(width: 168, height: 64)
    }
}

struct GlassSticky: View {
    let drop: Drop
    let now: Date
    let showsText: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let note = GlassKit.image("sticky") {
                note.renderingMode(.template).foregroundStyle(GlassKit.butter)
                if let shade = GlassKit.image("sticky-shade") { shade }
            } else {
                GlassNoteShape().fill(GlassKit.butter)
                GlassNoteFold().fill(GlassKit.paper.opacity(0.6))
            }
            if showsText {
                Text((drop.title ?? drop.rawText ?? "").lowercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GlassKit.ink)
                    .lineLimit(drop.dueAt == nil ? 4 : 3)
                    .minimumScaleFactor(0.85)
                    .frame(width: 100, height: drop.dueAt == nil ? 64 : 50, alignment: .topLeading)
                    .offset(x: 10, y: 25)
                if let due = drop.dueAt {
                    GlassCountdown(due: due, now: now)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(GlassKit.ink)
                        .frame(width: 76, height: 24, alignment: .leading)
                        .offset(x: 10, y: 84)
                }
            }
        }
        .frame(width: 120, height: 120, alignment: .topLeading)
    }
}

struct GlassCountdown: View {
    let due: Date
    let now: Date

    var body: some View {
        let remaining = due.timeIntervalSince(now)
        if remaining > 0, remaining < 3600 {
            Text(timerInterval: now...due, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.leading)
        } else {
            Text(GlassCopy.countdown(to: due, now: now))
        }
    }
}

struct GlassStub: View {
    let drop: Drop
    let now: Date
    let showsText: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let stub = GlassKit.image("ticket-stub") {
                stub
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(GlassKit.tomato)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(GlassKit.paper)
                    .frame(width: 132, height: 58)
                    .offset(x: 14, y: 9)
            }
            if showsText {
                VStack(alignment: .leading, spacing: 0) {
                    Text(GlassCopy.shortTitle(drop.title, limit: 4) ?? "")
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if let date {
                        Text(date)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(GlassKit.ink)
                .frame(width: 116, height: 48, alignment: .topLeading)
                .offset(x: 22, y: 14)
            }
        }
        .frame(width: 160, height: 76, alignment: .topLeading)
    }

    private var date: String? {
        GlassCopy.spoken(
            GlassCopy.frontLabel(dueAt: drop.dueAt, startsAt: drop.startsAt, whenLabel: drop.whenLabel, now: now),
            now: now
        )
    }
}

struct GlassPostcard: View {
    let drop: Drop
    let showsText: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: 68, height: 92)
                .overlay { picture }
                .clipped()
                .offset(x: 8, y: 8)
            if let card = GlassKit.image("postcard") {
                card
            } else {
                GlassWindowFrame(window: CGRect(x: 8, y: 8, width: 68, height: 92))
                    .fill(GlassKit.paper, style: FillStyle(eoFill: true))
            }
            if showsText {
                Text(GlassCopy.shortTitle(drop.title ?? drop.placeName, limit: 4) ?? GlassCopy.host(drop.url) ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .lineSpacing(0.8)
                    .foregroundStyle(GlassKit.ink)
                    .lineLimit(3)
                    .frame(width: 62, height: 44, alignment: .bottomLeading)
                    .offset(x: 88, y: 44)
            }
        }
        .frame(width: 160, height: 108, alignment: .topLeading)
    }

    @ViewBuilder private var picture: some View {
        if let image = GlassMedia.image(at: drop.thumbnailPath) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let map = GlassKit.image("postcard-map") {
            map
        } else {
            GlassStandInMap()
        }
    }
}

struct GlassPlayBadge: View {
    var body: some View {
        if let badge = GlassKit.image("play-badge") {
            badge
        } else {
            Circle()
                .fill(GlassKit.paper)
                .frame(width: 26, height: 26)
                .overlay {
                    Path { path in
                        path.move(to: CGPoint(x: 10.5, y: 8))
                        path.addLine(to: CGPoint(x: 18.5, y: 13))
                        path.addLine(to: CGPoint(x: 10.5, y: 18))
                        path.closeSubpath()
                    }
                    .fill(GlassKit.ink)
                }
                .frame(width: 28, height: 28)
        }
    }
}

struct GlassStandInPhoto: View {
    let id: UUID

    var body: some View {
        ZStack {
            GlassKit.sky
            Circle()
                .fill(GlassKit.butter)
                .frame(width: 18, height: 18)
                .offset(x: 18 + 12 * GlassLayout.unit(id, salt: 20), y: -20)
            Ellipse()
                .fill(GlassKit.mint)
                .frame(width: 120, height: 70)
                .offset(x: -24, y: 44)
            Ellipse()
                .fill(GlassKit.mint.opacity(0.8))
                .frame(width: 110, height: 60)
                .offset(x: 40, y: 52)
        }
    }
}

struct GlassStandInMap: View {
    var body: some View {
        ZStack {
            GlassKit.mint
            Capsule()
                .fill(GlassKit.sky)
                .frame(width: 120, height: 16)
                .rotationEffect(.degrees(32))
            Circle().fill(GlassKit.tomato).frame(width: 8, height: 8).offset(x: 10, y: -18)
        }
    }
}
