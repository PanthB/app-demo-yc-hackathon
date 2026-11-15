import SwiftUI

struct DropPreview: View {
    let face: PreviewFace
    let seed: UUID
    var ratio: CGFloat?

    var body: some View {
        Color.clear
            .aspectRatio(1 / (ratio ?? face.ratio), contentMode: .fit)
            .overlay { content }
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch face {
        case .image(let image):
            Image(uiImage: image).resizable().scaledToFill()
        case .cutout(let image):
            plate(alignment: .center) {
                Image(uiImage: image).resizable().scaledToFit()
            }
        case .words(let words):
            plate {
                Text(words)
                    .font(.title3.weight(.medium))
                    .lineLimit(face.ratio == 1 ? 5 : 3)
                    .multilineTextAlignment(.leading)
            }
        case .date(let top, let day):
            plate {
                VStack(alignment: .leading, spacing: 0) {
                    Text(top).font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                    Text(day).font(.largeTitle.bold()).monospacedDigit()
                }
            }
        case .countdown(let due):
            plate {
                Text(timerInterval: min(Date.now, due)...due, countsDown: true)
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(.tint)
            }
        case .waveform(let length):
            plate {
                VStack(alignment: .leading, spacing: 8) {
                    Waveform(seed: seed)
                    if let length {
                        Text(length).font(.title3.weight(.semibold)).monospacedDigit()
                    }
                }
            }
        case .symbol(let name):
            plate {
                Image(systemName: name).font(.largeTitle.weight(.semibold)).foregroundStyle(.tint)
            }
        }
    }

    private func plate(alignment: Alignment = .bottomLeading, @ViewBuilder _ content: () -> some View) -> some View {
        Rectangle()
            .fill(.tint.opacity(0.14))
            .overlay(alignment: alignment) { content().padding(12) }
    }
}

struct Waveform: View {
    let seed: UUID
    var bars = 24

    var body: some View {
        var random = StableRandom(seed, salt: 7)
        let heights = (0..<bars).map { _ in random.value(in: 6...36) }
        return HStack(alignment: .center, spacing: 3) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule().fill(.tint).frame(width: 3, height: heights[index])
            }
        }
        .frame(height: 36)
        .accessibilityHidden(true)
    }
}
