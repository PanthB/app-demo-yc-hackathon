import SwiftUI

struct DropRow: View {
    let drop: Drop
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        HStack(spacing: 12) {
            DropThumbnail(face: face, kind: drop.kind)
                .overlay {
                    if drop.kind == .video, face.fillsItsFrame { ClipBadge(length: nil) }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(drop.cardTitle(beside: .plain) ?? drop.linkHost ?? drop.kind.word)
                    .font(.headline)
                    .foregroundStyle(drop.zone == .done ? .secondary : .primary)
                    .lineLimit(2)
                if case .countdown(let due) = face {
                    Text(timerInterval: min(Date.now, due)...due, countsDown: true)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                } else if drop.isArriving, let suggestion = drop.liveSuggestion(now: now) {
                    SuggestionLine(suggestion: suggestion)
                } else if let meta = drop.cardMeta(now: now, beside: .plain) ?? drop.linkHost {
                    Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                KindPill(kind: drop.kind)
                PersonAvatar(drop: drop)
            }
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drop.spokenLabel(now: now, beside: .plain))
    }
}
