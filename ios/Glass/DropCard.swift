import SwiftUI

struct DropCard: View {
    let drop: Drop
    @Environment(BoardClock.self) private var clock

    static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        VStack(alignment: .leading, spacing: 0) {
            DropPreview(face: face, seed: drop.id)
            VStack(alignment: .leading, spacing: 4) {
                if let title = drop.cardTitle(beside: face) {
                    Text(title).font(.headline).lineLimit(2)
                }
                if let meta = drop.cardMeta(now: now, beside: face) {
                    Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }
                HStack(alignment: .top, spacing: 6) {
                    PersonAvatar(drop: drop)
                    if let suggestion = drop.liveSuggestion(now: now) {
                        SuggestionLine(suggestion: suggestion)
                    } else {
                        Text(drop.authorLabel).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.top, face.fillsItsFrame ? 12 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topLeading) {
            KindPill(kind: drop.kind).padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if drop.isPinned { PinBadge().padding(12) }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Self.shape)
        .contentShape(Self.shape)
        .contentShape(.contextMenuPreview, Self.shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: face))
        .accessibilityIdentifier("dropCard")
    }
}
