import SwiftUI

struct DropThumbnail: View {
    let face: PreviewFace
    let kind: DropKind
    let seed: UUID
    var side: CGFloat = 56
    var radius: CGFloat = 12
    var picture: URL?

    var body: some View {
        Color(.tertiarySystemFill)
            .frame(width: side, height: side)
            .overlay { small.dynamicTypeSize(.large) }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }

    private var roomy: Bool { side >= 72 }

    @ViewBuilder
    private var small: some View {
        switch face {
        case .image(let image):
            if let picture {
                DownsampledImage(url: picture, size: CGSize(width: side, height: side), glyph: kind.symbol, fallback: image)
            } else {
                Image(uiImage: image).resizable().scaledToFill()
            }
        case .cutout(let image):
            Image(uiImage: image).resizable().scaledToFit().padding(4)
        case .date(let top, let day):
            VStack(spacing: 0) {
                Text(top).font((roomy ? Font.caption : .caption2).weight(.semibold)).foregroundStyle(.tint)
                Text(day).font((roomy ? Font.title : .title3).bold()).monospacedDigit()
            }
        case .countdown(let due):
            Text(timerInterval: min(Date.now, due)...due, countsDown: true)
                .font((roomy ? Font.subheadline : .caption).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
        case .waveform:
            Waveform(seed: seed, bars: roomy ? 12 : 8)
        case .words(let words) where kind != .link:
            Text(words)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(roomy ? 5 : 4)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.leading)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .words, .plain:
            Image(systemName: kind.symbol).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
        }
    }
}
