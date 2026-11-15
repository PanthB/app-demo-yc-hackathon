import SwiftUI

struct KindPill: View {
    let symbol: String
    let word: String
    var onPicture = true
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 22

    init(kind: DropKind, onPicture: Bool = true) {
        self.init(symbol: kind.symbol, word: kind.word, onPicture: onPicture)
    }

    init(symbol: String, word: String, onPicture: Bool = true) {
        self.symbol = symbol
        self.word = word
        self.onPicture = onPicture
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(word)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(Color(.tertiarySystemFill).opacity(onPicture ? 0 : 1), in: .capsule)
        .glassEffect(onPicture ? .regular : .identity, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word)
    }
}

struct PinBadge: View {
    var onPicture = true
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 22

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.caption.weight(.semibold))
            .frame(width: side, height: side)
            .background(Color(.tertiarySystemFill).opacity(onPicture ? 0 : 1), in: .circle)
            .glassEffect(onPicture ? .regular : .identity, in: .circle)
            .accessibilityLabel("pinned")
    }
}

struct ClipBadge: View {
    let length: String?
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 22

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
            if let length {
                Text(length).monospacedDigit()
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, length == nil ? 0 : 8)
        .frame(minWidth: height, minHeight: height)
        .glassEffect(.regular, in: .capsule)
        .accessibilityHidden(true)
    }
}
