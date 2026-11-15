import SwiftUI

struct DropPreview: View {
    let face: PreviewFace
    let seed: UUID
    var pictureRatio: CGFloat?
    @ScaledMetric(relativeTo: .caption2) private var pillHeight: CGFloat = 22

    var body: some View {
        switch face {
        case .image(let image):
            Color.clear
                .aspectRatio(1 / (pictureRatio ?? face.ratio), contentMode: .fit)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipped()
        case .cutout(let image):
            Color.clear
                .aspectRatio(1 / face.ratio, contentMode: .fit)
                .overlay { Image(uiImage: image).resizable().scaledToFit().padding(12) }
        case .words, .date, .countdown, .waveform, .plain:
            hero
                .padding(.horizontal, 12)
                .padding(.top, pillHeight + 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var hero: some View {
        switch face {
        case .image, .cutout:
            EmptyView()
        case .plain:
            Color.clear.frame(height: 0)
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
