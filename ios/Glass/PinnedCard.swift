import SwiftUI

struct PinnedCard: View {
    let drop: Drop
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        HStack(spacing: 12) {
            DropThumbnail(face: face, kind: drop.kind, side: 80, radius: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(drop.cardTitle(beside: .plain) ?? drop.kind.word).font(.headline).lineLimit(1)
                if case .countdown(let due) = face {
                    Text(timerInterval: min(Date.now, due)...due, countsDown: true)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                } else if let meta = drop.cardMeta(now: now, beside: .plain) {
                    Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    KindPill(kind: drop.kind)
                    PersonAvatar(name: drop.cardAuthorName, personId: drop.cardAuthorId)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .padding(.trailing, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(DropCard.shape)
        .contentShape(DropCard.shape)
        .contentShape(.contextMenuPreview, DropCard.shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: .plain))
        .accessibilityIdentifier("pinnedCard")
    }
}
