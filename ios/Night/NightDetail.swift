import SwiftUI

struct NightDetail: View {
    let drop: Drop
    let palette: NightPalette

    @Environment(\.dropActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preview(face)
                VStack(alignment: .leading, spacing: 8) {
                    NightKindTag(kind: drop.kind, length: drop.mediaDuration.map(DropFace.duration))
                    Text(drop.cardTitle(beside: .plain) ?? face.words ?? drop.kind.word)
                        .font(NightStyle.title(34))
                        .tracking(-0.6)
                        .fixedSize(horizontal: false, vertical: true)
                    if let artist = CardWords.clean(drop.artist), drop.kind == .song {
                        Text(artist).font(.title3.weight(.medium)).foregroundStyle(NightStyle.secondary)
                    }
                    if let meta = drop.cardMeta(now: now, beside: .plain) {
                        Text(meta).font(.body).foregroundStyle(NightStyle.secondary).monospacedDigit()
                    }
                    if let suggestion = drop.liveSuggestion(now: now) {
                        SuggestionLine(suggestion: suggestion).font(.body)
                    }
                }
                HStack(spacing: 8) {
                    NightAvatar(name: drop.authorLabel, colorName: drop.authorColor, personId: drop.authorId, size: 26)
                    Text("\(drop.authorLabel) saved this \(drop.createdAt.formatted(.relative(presentation: .named)).lowercased()).")
                        .font(.subheadline)
                        .foregroundStyle(NightStyle.secondary)
                }
                actionsRow
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background { NightBackdrop(palette: palette, isLiving: false).overlay(Color.black.opacity(0.35)) }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func preview(_ face: PreviewFace) -> some View {
        switch face {
        case .image(let image), .cutout(let image):
            Color.clear
                .aspectRatio(1 / min(max(face.ratio, 0.6), 1.1), contentMode: .fit)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipShape(.rect(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
        default:
            NightCard(drop: drop, wide: true)
                .allowsHitTesting(false)
        }
    }

    private var actionsRow: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                NightActionTile(title: drop.isPinned ? "unpin" : "pin", symbol: drop.isPinned ? "pin.slash.fill" : "pin.fill") {
                    withAnimation(NightStyle.motion(reduceMotion)) { actions.pin(drop, !drop.isPinned) }
                }
                if drop.zone != .done {
                    NightActionTile(title: "done", symbol: "checkmark") {
                        withAnimation(NightStyle.motion(reduceMotion)) { actions.done(drop) }
                    }
                } else if drop.canUndoMove {
                    NightActionTile(title: "put back", symbol: "arrow.uturn.backward") {
                        withAnimation(NightStyle.motion(reduceMotion)) { actions.undo(drop) }
                    }
                }
                Menu {
                    let current = drop.boardZone(now: clock.now)
                    ForEach(Zone.allCases.filter { $0 != .done && $0 != current }, id: \.self) { zone in
                        Button(zone.displayName) {
                            withAnimation(NightStyle.motion(reduceMotion)) { actions.move(drop, zone) }
                        }
                    }
                } label: {
                    NightActionTile.label(title: "move", symbol: "arrow.right")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 22))
                if drop.url != nil {
                    NightActionTile(title: "open", symbol: "arrow.up.right", prominent: true) { actions.open(drop) }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: drop.isPinned)
        .sensoryFeedback(.success, trigger: drop.zone == .done)
    }
}

private struct NightActionTile: View {
    let title: String
    let symbol: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        if prominent {
            Button(action: action) { Self.label(title: title, symbol: symbol) }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 22))
        } else {
            Button(action: action) { Self.label(title: title, symbol: symbol) }
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 22))
        }
    }

    static func label(title: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.body.weight(.semibold))
            Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
    }
}
