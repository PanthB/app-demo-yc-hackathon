import SwiftUI

struct SuggestionCard: View {
    let suggestion: FeedSuggestion
    let drops: [UUID: Drop]
    let save: () -> Void
    let dismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let pill = suggestion.pill
        let top = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        VStack(alignment: .leading, spacing: 12) {
            top {
                FeedThumb(picture: nil, link: suggestion.thumbnailUrl, symbol: pill.symbol)
                VStack(alignment: .leading, spacing: 4) {
                    KindPill(symbol: pill.symbol, word: pill.word, onPicture: false)
                        .padding(.bottom, 2)
                    Text(suggestion.title).font(.headline).lineLimit(3).accessibilityIdentifier("suggestionTitle")
                    if let meta = suggestion.meta(now: .now) {
                        Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let words = suggestion.blurb {
                Text(words).font(.subheadline).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.reason).font(.subheadline).lineLimit(3)
                ForEach(suggestion.inspiredBy ?? [], id: \.clientId) { source in
                    let drop = drops[DropKey.id(for: source.clientId)]
                    HStack(spacing: 8) {
                        FeedThumb(picture: picture(of: drop), link: source.thumbnailUrl, symbol: drop?.kind.symbol ?? "square.on.square", side: 28, radius: 7)
                        Text(CardWords.clean(source.title) ?? "something on the board")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actions }
                VStack(alignment: .leading, spacing: 8) { actions }
            }
            .font(.subheadline.weight(.semibold))
            .buttonBorderShape(.capsule)
            .padding(.top, 2)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(DropCard.shape)
    }

    @ViewBuilder
    private var actions: some View {
        Button("save to board", action: save)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("suggestionSave")
        Button("dismiss", action: dismiss)
            .buttonStyle(.bordered)
            .tint(.primary)
            .accessibilityIdentifier("suggestionDismiss")
        if let link = suggestion.link {
            Link(destination: link) {
                Label("open", systemImage: "arrow.up.right")
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .accessibilityLabel("open \(suggestion.site ?? "the link")")
            .accessibilityIdentifier("suggestionLink")
        }
    }

    private func picture(of drop: Drop?) -> UIImage? {
        switch drop?.previewFace(now: .now) {
        case .image(let image), .cutout(let image): image
        default: nil
        }
    }
}

struct FeedThumb: View {
    let picture: UIImage?
    let link: String?
    let symbol: String
    var side: CGFloat = 88
    var radius: CGFloat = 14

    private var url: URL? {
        guard let link, var parts = URLComponents(string: link) else { return nil }
        if parts.scheme == "http" { parts.scheme = "https" }
        return parts.url
    }

    var body: some View {
        Color(.tertiarySystemFill)
            .frame(width: side, height: side)
            .overlay {
                if let picture {
                    Image(uiImage: picture).resizable().scaledToFill()
                } else {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: symbol)
                                .font((side >= 56 ? Font.title2 : .caption).weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}
