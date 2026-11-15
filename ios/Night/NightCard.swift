import SwiftUI

struct NightCard: View {
    let drop: Drop
    var wide = false
    @Environment(BoardClock.self) private var clock
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: NightPicture?

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        let path = imagePath(face)
        let key = path.map { NightImage.cacheKey($0, pixels: pixels) }
        let shown = key.flatMap { key in NightImage.cached(key) ?? (loaded?.key == key ? loaded : nil) }
        VStack(alignment: .leading, spacing: 0) {
            media(face, path: path, key: key, shown: shown)
            details(face: face, now: now)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(face.fillsItsFrame ? shown?.tone ?? NightStyle.surface : NightStyle.surface)
        .clipShape(NightStyle.card)
        .overlay { NightStyle.card.strokeBorder(NightStyle.hairline, lineWidth: 1) }
        .contentShape(NightStyle.card)
        .contentShape(.contextMenuPreview, NightStyle.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: face))
        .accessibilityIdentifier("nightCard")
    }

    private var pixels: Int {
        Int(((wide || typeSize.isAccessibilitySize) ? 400 : 200) * displayScale)
    }

    private func imagePath(_ face: PreviewFace) -> String? {
        switch face {
        case .cutout: drop.cutoutPath
        case .image: MediaStore.image(at: drop.thumbnailPath) != nil ? drop.thumbnailPath : drop.mediaPaths.first
        default: nil
        }
    }

    @ViewBuilder
    private func media(_ face: PreviewFace, path: String?, key: String?, shown: NightPicture?) -> some View {
        switch face {
        case .image, .cutout:
            Color.clear
                .aspectRatio(1 / ratio(face), contentMode: .fit)
                .overlay {
                    if let shown {
                        artwork(face, shown.image).transition(.opacity)
                    } else {
                        NightSkeleton().transition(.opacity)
                    }
                }
                .clipped()
                .overlay(alignment: .topLeading) { badges }
                .task(id: key) { await load(path) }
        default:
            badges
        }
    }

    @ViewBuilder
    private func artwork(_ face: PreviewFace, _ image: CGImage) -> some View {
        if case .cutout = face {
            Image(decorative: image, scale: displayScale).resizable().scaledToFit().padding(NightStyle.inset)
        } else {
            Image(decorative: image, scale: displayScale).resizable().scaledToFill()
        }
    }

    private func load(_ path: String?) async {
        guard let path else { return }
        if let cached = NightImage.cached(NightImage.cacheKey(path, pixels: pixels)) {
            loaded = cached
            return
        }
        let toneKey = drop.thumbnailPath ?? drop.cutoutPath ?? drop.mediaPaths.first ?? drop.id.uuidString
        guard let picture = await NightImage.load(path, toneKey: toneKey, pixels: pixels), !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) { loaded = picture }
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
        case .song: return 0.9
        case .video: return 1.1
        default: return min(max(face.ratio, 0.75), 1.1)
        }
    }

    private func details(face: PreviewFace, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            lead(face)
            if let title = drop.cardTitle(beside: face) {
                Text(title).font(NightStyle.itemTitle).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            }
            if let meta = meta(face: face, now: now) {
                Text(meta).font(NightStyle.body).foregroundStyle(NightStyle.secondary).monospacedDigit().lineLimit(2)
            }
            if drop.isArriving {
                SuggestionLine(suggestion: .words("reading this one now.")).font(NightStyle.body)
            }
            NightByline(drop: drop).padding(.top, 2)
        }
        .padding(.horizontal, NightStyle.inset)
        .padding(.top, face.fillsItsFrame ? 10 : 0)
        .padding(.bottom, 10)
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
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
