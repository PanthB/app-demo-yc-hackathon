import SwiftUI

struct NightCard: View {
    let drop: Drop
    var wide = false
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        VStack(alignment: .leading, spacing: 0) {
            media(face)
            details(face: face, now: now)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background(face))
        .clipShape(NightStyle.card)
        .overlay { NightStyle.card.strokeBorder(NightStyle.hairline, lineWidth: 1) }
        .contentShape(NightStyle.card)
        .contentShape(.contextMenuPreview, NightStyle.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: face))
        .accessibilityIdentifier("nightCard")
    }

    @ViewBuilder
    private func media(_ face: PreviewFace) -> some View {
        switch face {
        case .image(let image), .cutout(let image):
            Color.clear
                .aspectRatio(1 / ratio(face), contentMode: .fit)
                .overlay {
                    if case .cutout = face {
                        Image(uiImage: image).resizable().scaledToFit().padding(NightStyle.inset)
                    } else {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipped()
                .overlay(alignment: .topLeading) { badges }
        default:
            badges
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            NightKindTag(kind: drop.kind, length: drop.kind == .video ? drop.mediaDuration.map(DropFace.duration) : nil)
            Spacer(minLength: 0)
            if drop.isPinned { NightPinBadge() }
        }
        .padding(NightStyle.inset)
    }

    private func ratio(_ face: PreviewFace) -> CGFloat {
        if wide { return 9 / 16 }
        switch drop.kind {
        case .song: return 1
        case .video: return 1.25
        default: return min(max(face.ratio, 0.75), 1.25)
        }
    }

    private func details(face: PreviewFace, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            lead(face)
            if let title = drop.cardTitle(beside: face) {
                Text(title).font(NightStyle.itemTitle).lineLimit(2)
            }
            if let meta = meta(face: face, now: now) {
                Text(meta).font(NightStyle.body).foregroundStyle(NightStyle.secondary).monospacedDigit().lineLimit(1)
            }
            if let suggestion = drop.liveSuggestion(now: now) {
                SuggestionLine(suggestion: suggestion).font(NightStyle.body)
            }
            NightByline(drop: drop).padding(.top, 4)
        }
        .padding(.horizontal, NightStyle.inset)
        .padding(.top, face.fillsItsFrame ? NightStyle.inset : 0)
        .padding(.bottom, NightStyle.inset)
    }

    private func meta(face: PreviewFace, now: Date) -> String? {
        if drop.kind == .song { return CardWords.clean(drop.artist) }
        return drop.cardMeta(now: now, beside: face)
    }

    @ViewBuilder
    private func lead(_ face: PreviewFace) -> some View {
        switch face {
        case .words(let words):
            Text(words)
                .font(NightStyle.heading)
                .lineLimit(drop.kind == .link ? 1 : 5)
                .minimumScaleFactor(drop.kind == .link ? 0.7 : 1)
                .padding(.bottom, 4)
        case .date(let top, let day):
            NightDateTile(top: top, day: day).padding(.bottom, 4)
        case .countdown(let due):
            Label {
                Text(timerInterval: min(Date.now, due)...due, countsDown: true).monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
            .font(NightStyle.heading)
            .foregroundStyle(.tint)
            .padding(.bottom, 4)
        case .waveform(let length):
            HStack(spacing: 8) {
                Waveform(seed: drop.id, bars: 18).tint(.white.opacity(0.85))
                if let length {
                    Text(length).font(NightStyle.body.weight(.semibold)).monospacedDigit().foregroundStyle(NightStyle.secondary)
                }
            }
            .padding(.bottom, 4)
        case .image, .cutout, .plain:
            EmptyView()
        }
    }

    private func background(_ face: PreviewFace) -> Color {
        guard drop.kind == .song, case .image(let art) = face else { return NightStyle.surface }
        return ArtworkTone.color(of: art, key: drop.thumbnailPath ?? drop.id.uuidString)
    }
}

struct NightByline: View {
    let drop: Drop

    var body: some View {
        HStack(spacing: 8) {
            NightAvatar(name: drop.authorLabel, colorName: drop.authorColor, personId: drop.authorId)
            Text(drop.authorLabel).font(NightStyle.body).foregroundStyle(NightStyle.secondary).lineLimit(1)
        }
    }
}

struct NightDateTile: View {
    let top: String
    let day: String

    var body: some View {
        VStack(spacing: 0) {
            Text(top).font(NightStyle.caption).foregroundStyle(.tint)
            Text(day).font(NightStyle.heading).monospacedDigit()
        }
        .frame(width: 52, height: 52)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12, style: .continuous))
    }
}

struct NightKindTag: View {
    let kind: DropKind
    var length: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbol).fontWeight(NightStyle.symbolWeight)
            Text(kind.word)
            if let length {
                Text(length).monospacedDigit().foregroundStyle(NightStyle.secondary)
            }
        }
        .font(NightStyle.caption)
        .padding(.horizontal, 8)
        .frame(height: NightStyle.pillHeight)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(length.map { "\(kind.word), \($0)" } ?? kind.word)
    }
}

struct NightPinBadge: View {
    var body: some View {
        Image(systemName: "pin.fill")
            .font(NightStyle.caption)
            .frame(width: NightStyle.pillHeight, height: NightStyle.pillHeight)
            .glassEffect(.regular, in: .circle)
            .accessibilityLabel("pinned")
    }
}

struct NightAvatar: View {
    let name: String
    let colorName: String?
    let personId: String
    var size: CGFloat = NightStyle.avatar

    private static let fallbacks: [Color] = [.pink, .orange, .purple, .blue, .teal, .green]

    var body: some View {
        Text(PersonMark.initial(of: name))
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: .circle)
            .accessibilityLabel(name)
    }

    var color: Color {
        switch colorName?.lowercased() {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        case "gray": .gray
        default: Self.fallbacks[PersonMark.colorIndex(for: personId, count: Self.fallbacks.count)]
        }
    }
}
