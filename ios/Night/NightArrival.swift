import SwiftUI

struct NightArrivalItem: Equatable {
    let id: UUID
    let text: String
}

struct NightArrivalBanner: View {
    let drop: Drop
    let text: String
    let open: () -> Void
    let dismiss: () -> Void

    @State private var picture: NightPicture?
    @State private var lift: CGFloat = 0

    private var path: String? {
        drop.thumbnailPath ?? drop.cutoutPath ?? (drop.sourceKind == .image ? drop.mediaPaths.first : nil)
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                NightAvatar(name: CardWords.clean(drop.authorName) ?? "someone", colorName: drop.authorColor, personId: drop.authorId, size: 34)
                Text(text)
                    .font(NightStyle.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    if let picture {
                        Image(decorative: picture.image, scale: 1)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: drop.kind.symbol)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
        .offset(y: min(lift, 0))
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { lift = $0.translation.height }
                .onEnded { value in
                    if value.translation.height < -24 {
                        dismiss()
                    } else {
                        withAnimation(.snappy) { lift = 0 }
                    }
                }
        )
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHint("shows it in its group")
        .accessibilityIdentifier("nightArrivalBanner")
        .task(id: path) {
            guard let path else { return }
            if let cached = NightImage.cached(NightImage.cacheKey(path, pixels: 126)) {
                picture = cached
                return
            }
            let loaded = await NightImage.load(path, toneKey: path, pixels: 126)
            withAnimation(.easeOut(duration: 0.2)) { picture = loaded }
        }
    }
}
