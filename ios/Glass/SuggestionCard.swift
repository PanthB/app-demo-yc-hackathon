import SwiftUI

struct SuggestionCard: View {
    let suggestion: FeedSuggestion
    let vibe: String
    let save: () -> Void
    let dismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var pillHeight: CGFloat = 22

    var body: some View {
        let pill = suggestion.pill
        let top = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        VStack(alignment: .leading, spacing: 12) {
            top {
                FeedThumb(link: suggestion.thumbnailUrl, symbol: pill.symbol)
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
            Text(vibe)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: pillHeight)
                .background(Color(.tertiarySystemFill), in: .capsule)
                .accessibilityLabel("fits \(vibe)")
                .accessibilityIdentifier("suggestionVibe")
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
}

struct FeedThumb: View {
    let link: String?
    let symbol: String
    var side: CGFloat = 88
    var radius: CGFloat = 14

    var body: some View {
        DownsampledImage(url: link.flatMap(URL.init(string:)), size: CGSize(width: side, height: side), glyph: symbol)
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}
