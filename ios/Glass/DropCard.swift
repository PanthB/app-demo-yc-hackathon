import SwiftUI

struct DropCard: View {
    let drop: Drop
    var previewRatio: CGFloat?
    @Environment(BoardClock.self) private var clock

    static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        VStack(alignment: .leading, spacing: 0) {
            DropPreview(face: face, seed: drop.id, ratio: previewRatio)
                .overlay(alignment: .topLeading) {
                    KindPill(kind: drop.kind).padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    if drop.pinned { PinBadge().padding(8) }
                }
            VStack(alignment: .leading, spacing: 4) {
                if let title = drop.cardTitle(beside: face) {
                    Text(title).font(.headline).lineLimit(2)
                }
                if let meta = drop.cardMeta(now: now, beside: face) {
                    Text(meta).font(.subheadline).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }
                HStack(alignment: .top, spacing: 6) {
                    PersonAvatar(name: drop.cardAuthorName, personId: drop.cardAuthorId)
                    if let suggestion = drop.suggestion(now: now) {
                        SuggestionLine(suggestion: suggestion)
                    } else {
                        Text(drop.cardAuthorName).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Self.shape)
        .contentShape(Self.shape)
        .contentShape(.contextMenuPreview, Self.shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: face))
        .accessibilityIdentifier("dropCard")
    }
}
