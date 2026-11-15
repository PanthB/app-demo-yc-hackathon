import SwiftUI

struct PinnedCard: View {
    let drop: Drop
    @Environment(BoardClock.self) private var clock
    @ScaledMetric(relativeTo: .headline) private var block: CGFloat = 92

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        HStack(spacing: 12) {
            if face.drawsSmall {
                DropThumbnail(face: face, kind: drop.kind, seed: drop.id, side: 80, radius: 14)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(drop.cardTitle(beside: .plain) ?? face.words ?? drop.kind.word).font(.headline).lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: "pin.fill").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                if let meta = drop.cardMeta(now: now, beside: .plain) {
                    Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    KindPill(kind: drop.kind, onPicture: false)
                    PersonAvatar(drop: drop)
                    Text(drop.authorLabel).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: block, alignment: .leading)
            .padding(.leading, face.drawsSmall ? 0 : 4)
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
