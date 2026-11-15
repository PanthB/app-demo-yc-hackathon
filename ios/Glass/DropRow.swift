import SwiftUI

struct DropRow: View {
    let drop: Drop
    @Environment(BoardClock.self) private var clock
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        HStack(spacing: 12) {
            DropThumbnail(face: face, kind: drop.kind, seed: drop.id, picture: drop.pictureURL(for: face))
                .overlay {
                    if drop.kind == .video, face.fillsItsFrame { ClipBadge(length: nil).dynamicTypeSize(.large) }
                }
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drop.cardTitle(beside: .plain) ?? face.words ?? drop.kind.word)
                        .font(.headline)
                        .foregroundStyle(drop.zone == .done ? .secondary : .primary)
                        .lineLimit(2)
                    if drop.isArriving, let suggestion = drop.liveSuggestion(now: now) {
                        SuggestionLine(suggestion: suggestion)
                    } else if let meta = drop.cardMeta(now: now, beside: .plain) ?? drop.linkHost {
                        Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    KindPill(kind: drop.kind, onPicture: false)
                    PersonAvatar(drop: drop)
                }
            }
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: .plain))
    }
}
