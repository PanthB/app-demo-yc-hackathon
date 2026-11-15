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
            VStack(alignment: .leading, spacing: 16) {
                preview(face)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        NightKindTag(kind: drop.kind, length: drop.mediaDuration.map(DropFace.duration))
                        if drop.isPinned { NightPinBadge() }
                    }
                    Text(drop.cardTitle(beside: .plain) ?? face.words ?? drop.kind.word)
                        .font(NightStyle.pageTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if let meta = drop.kind == .song ? CardWords.clean(drop.artist) : drop.cardMeta(now: now, beside: .plain) {
                        Text(meta).font(NightStyle.itemTitle.weight(.regular)).foregroundStyle(NightStyle.secondary).monospacedDigit()
                    }
                    if let suggestion = drop.liveSuggestion(now: now) {
                        SuggestionLine(suggestion: suggestion).font(NightStyle.body)
                    }
                }
                HStack(spacing: 8) {
                    NightAvatar(name: drop.authorLabel, colorName: drop.authorColor, personId: drop.authorId)
                    Text("\(drop.authorLabel) saved this \(drop.createdAt.formatted(.relative(presentation: .named)).lowercased()).")
                        .font(NightStyle.body)
                        .foregroundStyle(NightStyle.secondary)
                }
                actionsRow.padding(.top, 8)
            }
            .padding(.horizontal, NightStyle.margin)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background { NightBackdrop(palette: palette, isLiving: false).overlay(Color.black.opacity(0.4)) }
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
                .clipShape(NightStyle.card)
                .overlay { NightStyle.card.strokeBorder(NightStyle.hairline, lineWidth: 1) }
        default:
            NightCard(drop: drop, wide: true)
                .allowsHitTesting(false)
        }
    }

    private var actionsRow: some View {
        HStack(alignment: .top, spacing: 8) {
            GlassEffectContainer(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    iconButton(drop.isPinned ? "unpin" : "pin", symbol: drop.isPinned ? "pin.slash" : "pin") {
                        actions.pin(drop, !drop.isPinned)
                    }
                    if drop.zone != .done {
                        iconButton("done", symbol: "checkmark") { actions.done(drop) }
                    } else if drop.canUndoMove {
                        iconButton("put it back", symbol: "arrow.uturn.backward") { actions.undo(drop) }
                    }
                    captioned("move") {
                        Menu {
                            let current = drop.boardZone(now: clock.now)
                            ForEach(Zone.allCases.filter { $0 != .done && $0 != current }, id: \.self) { zone in
                                Button(zone.displayName) {
                                    withAnimation(NightStyle.motion(reduceMotion)) { actions.move(drop, zone) }
                                }
                            }
                        } label: {
                            Label("move to", systemImage: "arrow.right")
                                .labelStyle(.iconOnly)
                                .frame(width: NightStyle.target, height: NightStyle.target)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
            if drop.url != nil {
                Button {
                    actions.open(drop)
                } label: {
                    Label("open", systemImage: "arrow.up.right")
                }
                .buttonStyle(NightPrimaryButtonStyle())
            }
        }
        .font(NightStyle.body.weight(NightStyle.symbolWeight))
        .foregroundStyle(.white)
        .sensoryFeedback(.impact(weight: .light), trigger: drop.isPinned)
        .sensoryFeedback(.success, trigger: drop.zone == .done)
    }

    private func iconButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        captioned(title) {
            Button {
                withAnimation(NightStyle.motion(reduceMotion)) { action() }
            } label: {
                Label(title, systemImage: symbol)
                    .labelStyle(.iconOnly)
                    .frame(width: NightStyle.target, height: NightStyle.target)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    private func captioned(_ title: String, @ViewBuilder control: () -> some View) -> some View {
        VStack(spacing: 6) {
            control()
            Text(title)
                .font(NightStyle.caption)
                .foregroundStyle(NightStyle.secondary)
                .accessibilityHidden(true)
        }
        .frame(minWidth: NightStyle.target + 12)
    }
}
