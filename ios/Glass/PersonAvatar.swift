import SwiftUI

struct PersonAvatar: View {
    let name: String
    let personId: String
    @ScaledMetric(relativeTo: .footnote) var size: CGFloat = 18

    private static let colors: [Color] = [.pink, .orange, .purple, .blue, .teal, .green]

    var body: some View {
        Text(PersonMark.initial(of: name))
            .font(.system(size: size * 0.56, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Self.colors[PersonMark.colorIndex(for: personId, count: Self.colors.count)], in: .circle)
            .accessibilityLabel(name)
    }
}
