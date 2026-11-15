import SwiftUI

struct PersonAvatar: View {
    let name: String
    let colorName: String?
    let personId: String
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 18

    private static let fallbacks: [Color] = [.pink, .orange, .purple, .blue, .teal, .green]

    init(drop: Drop) {
        name = drop.authorLabel
        colorName = drop.authorColor
        personId = drop.authorId
    }

    var body: some View {
        Text(PersonMark.initial(of: name))
            .font(.system(size: size * 0.56, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: .circle)
            .accessibilityLabel(name)
    }

    private var color: Color {
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
