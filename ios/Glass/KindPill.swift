import SwiftUI

struct KindPill: View {
    let kind: DropKind
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 22

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: kind.symbol)
            Text(kind.word)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .frame(height: height)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.word)
    }
}

struct PinBadge: View {
    @ScaledMetric(relativeTo: .caption2) private var side: CGFloat = 22

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.caption2.weight(.semibold))
            .frame(width: side, height: side)
            .glassEffect(.regular, in: .circle)
            .accessibilityLabel("pinned")
    }
}
