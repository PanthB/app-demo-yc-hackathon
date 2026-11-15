import SwiftUI

struct DropPreview: View {
    let face: PreviewFace
    let seed: UUID
    var ratio: CGFloat?
    @ScaledMetric(relativeTo: .caption2) private var pillHeight: CGFloat = 22

    var body: some View {
        switch face {
        case .image(let image):
            framed(ratio ?? face.ratio) {
                Image(uiImage: image).resizable().scaledToFill()
            }
        case .cutout(let image):
            framed(ratio ?? face.ratio) {
                Image(uiImage: image).resizable().scaledToFit().padding(12)
            }
        case .words, .date, .countdown, .waveform, .symbol:
            if let ratio {
                framed(ratio) {
                    Color.clear.overlay(alignment: .bottomLeading) {
                        hero.padding(.horizontal, 12)
                    }
                }
            } else {
                hero
                    .padding(.horizontal, 12)
                    .padding(.top, pillHeight + 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func framed(_ ratio: CGFloat, @ViewBuilder _ content: () -> some View) -> some View {
        Color.clear
            .aspectRatio(1 / ratio, contentMode: .fit)
            .overlay { content() }
            .clipped()
    }

    @ViewBuilder
    private var hero: some View {
        switch face {
        case .image, .cutout:
            EmptyView()
        case .words(let words):
            Text(words)
                .font(.title3.weight(.medium))
                .lineLimit(5)
                .multilineTextAlignment(.leading)
        case .date(let top, let day):
            VStack(alignment: .leading, spacing: 0) {
                Text(top).font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                Text(day).font(.largeTitle.bold()).monospacedDigit()
            }
        case .countdown(let due):
            Text(timerInterval: min(Date.now, due)...due, countsDown: true)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(.tint)
        case .waveform(let length):
            VStack(alignment: .leading, spacing: 4) {
                Waveform(seed: seed)
                if let length {
                    Text(length).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.tint)
                }
            }
        case .symbol(let name):
            if ratio != nil {
                Image(systemName: name).font(.largeTitle.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
    }
}

struct Waveform: View {
    let seed: UUID
    var bars = 26

    var body: some View {
        var random = StableRandom(seed, salt: 7)
        let heights = (0..<bars).map { _ in random.value(in: 5...32) }
        return HStack(alignment: .center, spacing: 3) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule().fill(.tint).frame(width: 3, height: heights[index])
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}
