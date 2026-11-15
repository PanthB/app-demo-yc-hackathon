import SwiftUI

struct NightCard: View {
    let drop: Drop
    var wide = false
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        content(face: face, now: now)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topLeading) {
                NightKindTag(kind: drop.kind, length: drop.kind == .video ? drop.mediaDuration.map(DropFace.duration) : nil)
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if drop.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2.weight(.bold))
                        .frame(width: 26, height: 26)
                        .glassEffect(.regular, in: .circle)
                        .padding(12)
                        .accessibilityLabel("pinned")
                }
            }
            .background(NightStyle.surface)
            .clipShape(NightStyle.card)
            .overlay { NightStyle.card.strokeBorder(NightStyle.hairline, lineWidth: 1) }
            .contentShape(NightStyle.card)
            .contentShape(.contextMenuPreview, NightStyle.card)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(drop.spokenLabel(now: now, beside: face))
            .accessibilityIdentifier("nightCard")
    }

    @ViewBuilder
    private func content(face: PreviewFace, now: Date) -> some View {
        switch (drop.kind, face) {
        case (.song, .image(let art)):
            song(art: art, now: now)
        case (.place, .image(let image)):
            place(image, face: face, now: now)
        case (_, .image(let image)):
            poster(image, face: face, now: now)
        default:
            plate(face: face, now: now)
        }
    }

    private func song(art: UIImage, now: Date) -> some View {
        let tone = ArtworkTone.color(of: art, key: drop.thumbnailPath ?? drop.id.uuidString)
        let layout = wide ? AnyLayout(HStackLayout(alignment: .center, spacing: 14)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        return layout {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { Image(uiImage: art).resizable().scaledToFill() }
                .clipShape(.rect(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: wide ? 132 : .infinity)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            VStack(alignment: .leading, spacing: 3) {
                if wide { Spacer(minLength: 30) }
                Text(drop.cardTitle(beside: .plain) ?? "a song")
                    .font(wide ? .title3.weight(.bold) : .headline.weight(.bold))
                    .lineLimit(wide ? 3 : 2)
                if let artist = CardWords.clean(drop.artist) {
                    Text(artist).font(.subheadline).foregroundStyle(NightStyle.secondary).lineLimit(1)
                }
                footer(now: now).padding(.top, 8)
            }
        }
        .padding(wide ? 12 : 10)
        .padding(.bottom, wide ? 0 : 4)
        .background(LinearGradient(colors: [tone, tone.mix(with: NightStyle.surface, by: 0.55)], startPoint: .top, endPoint: .bottom))
    }

    private func poster(_ image: UIImage, face: PreviewFace, now: Date) -> some View {
        let ratio: CGFloat = wide ? 0.62 : (drop.kind == .video ? 1.32 : min(max(face.ratio, 1), 1.3))
        return Color.clear
            .aspectRatio(1 / ratio, contentMode: .fit)
            .overlay { Image(uiImage: image).resizable().scaledToFill() }
            .clipped()
            .overlay {
                LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .black.opacity(0.55), location: 0.62), .init(color: .black.opacity(0.92), location: 1)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = drop.cardTitle(beside: face) {
                        Text(title)
                            .font(wide ? .title2.weight(.heavy) : .headline.weight(.bold))
                            .lineLimit(3)
                    }
                    if let meta = drop.cardMeta(now: now, beside: face) {
                        Text(meta).font(.footnote).foregroundStyle(.white.opacity(0.75)).monospacedDigit().lineLimit(1)
                    }
                    footer(now: now)
                        .tint(.white.opacity(0.92))
                        .padding(.top, 2)
                }
                .padding(14)
            }
    }

    private func place(_ image: UIImage, face: PreviewFace, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(wide ? 1.9 : 1.15, contentMode: .fit)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipShape(.rect(cornerRadius: NightStyle.cardRadius - 8, style: .continuous))
                .padding(6)
            VStack(alignment: .leading, spacing: 4) {
                Text(drop.cardTitle(beside: face) ?? drop.placeName ?? "a place")
                    .font(wide ? .title2.weight(.heavy) : .headline.weight(.bold))
                    .lineLimit(2)
                if let meta = drop.cardMeta(now: now, beside: face) {
                    Label(meta, systemImage: "mappin")
                        .labelStyle(TightLabel())
                        .font(.footnote)
                        .foregroundStyle(NightStyle.secondary)
                        .lineLimit(1)
                }
                footer(now: now).padding(.top, 6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 14)
        }
    }

    private func plate(face: PreviewFace, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            hero(face)
                .frame(maxWidth: .infinity, minHeight: wide ? 90 : 70, alignment: .bottomLeading)
                .padding(.top, 40)
            VStack(alignment: .leading, spacing: 4) {
                if let title = drop.cardTitle(beside: face) {
                    Text(title).font(.headline.weight(.bold)).lineLimit(2)
                }
                if let meta = drop.cardMeta(now: now, beside: face) {
                    Text(meta).font(.footnote).foregroundStyle(NightStyle.secondary).monospacedDigit().lineLimit(1)
                }
                footer(now: now).padding(.top, 4)
            }
        }
        .padding(14)
        .background { NightGradientPlate(seed: drop.id) }
    }

    @ViewBuilder
    private func hero(_ face: PreviewFace) -> some View {
        switch face {
        case .words(let words) where drop.kind == .link:
            Text(words)
                .font(.system(wide ? .title : .title2, weight: .heavy))
                .tracking(-0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        case .words(let words):
            Text(words)
                .font(.system(wide ? .title : .title2, design: .serif).weight(.semibold))
                .lineLimit(wide ? 4 : 6)
                .minimumScaleFactor(0.8)
        case .date(let top, let day):
            VStack(alignment: .leading, spacing: -4) {
                Text(top).font(.headline.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                Text(day).font(NightStyle.title(56)).monospacedDigit()
            }
        case .countdown(let due):
            Text(timerInterval: min(Date.now, due)...due, countsDown: true)
                .font(NightStyle.title(44))
                .monospacedDigit()
        case .waveform(let length):
            VStack(alignment: .leading, spacing: 6) {
                Waveform(seed: drop.id).tint(.white)
                if let length { Text(length).font(.subheadline.weight(.semibold)).monospacedDigit() }
            }
        case .image(let image), .cutout(let image):
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
        case .plain:
            Image(systemName: drop.kind.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func footer(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let suggestion = drop.liveSuggestion(now: now) {
                SuggestionLine(suggestion: suggestion)
            }
            HStack(spacing: 6) {
                NightAvatar(name: drop.authorLabel, colorName: drop.authorColor, personId: drop.authorId, size: 20)
                Text(drop.authorLabel).font(.footnote.weight(.medium)).foregroundStyle(NightStyle.secondary).lineLimit(1)
            }
        }
    }
}

struct NightKindTag: View {
    let kind: DropKind
    var length: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbol)
            Text(kind.word)
            if let length {
                Text(length).monospacedDigit().foregroundStyle(.white.opacity(0.7))
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .frame(height: 26)
        .glassEffect(.regular.tint(.black.opacity(0.18)), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.word)
    }
}

struct NightAvatar: View {
    let name: String
    let colorName: String?
    let personId: String
    var size: CGFloat = 28

    private static let fallbacks: [Color] = [.pink, .orange, .purple, .blue, .teal, .green]

    var body: some View {
        Text(PersonMark.initial(of: name))
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .circle)
            .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
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

private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
