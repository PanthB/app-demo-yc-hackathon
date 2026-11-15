import SwiftUI

struct DropDetailView: View {
    let drop: Drop
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions
    @Environment(\.dismiss) private var dismiss
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let face = drop.previewFace(now: now)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DropPreview(face: face, seed: drop.id, pictureRatio: drop.kind == .song ? 1 : min(face.ratio, 1))
                    .padding(.bottom, face.fillsItsFrame ? 0 : 24)
                    .overlay(alignment: .bottomLeading) {
                        if drop.kind == .video, face.fillsItsFrame {
                            ClipBadge(length: drop.mediaDuration.map(DropFace.duration)).padding(12)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        KindPill(kind: drop.kind).padding(12)
                    }
                    .overlay(alignment: .topTrailing) {
                        if drop.isPinned { PinBadge().padding(12) }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(DropCard.shape)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(drop.cardTitle(beside: .plain) ?? drop.linkHost ?? drop.kind.word)
                        .font(.title2.weight(.bold))
                    if let meta = drop.cardMeta(now: now, beside: .plain) {
                        Text(meta).font(.body).foregroundStyle(.secondary).monospacedDigit()
                    }
                    if let suggestion = drop.liveSuggestion(now: now) {
                        SuggestionLine(suggestion: suggestion).padding(.top, 4)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PersonAvatar(drop: drop)
                        Text("\(CardWords.saver(drop.authorName, isMe: drop.authorId == DeviceIdentity.personId)) saved this \(Text(drop.createdAt, format: .relative(presentation: .named))).")
                    }
                    if let host = drop.linkHost {
                        Label(host, systemImage: "link")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaBar(edge: .bottom) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(motion) { actions.pin(drop, !drop.isPinned) }
                    } label: {
                        Label(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    Menu {
                        ZoneMenu(drop: drop)
                    } label: {
                        Label("move to", systemImage: "arrow.right")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    if drop.url != nil {
                        if drop.zone != .done {
                            doneButton.buttonStyle(.glass).buttonBorderShape(.circle)
                        }
                        Button {
                            actions.open(drop)
                        } label: {
                            Label(drop.kind.openWord, systemImage: "arrow.up.right")
                                .labelStyle(.titleAndIcon)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    } else if drop.zone != .done {
                        doneButton.labelStyle(.titleAndIcon).buttonStyle(.glassProminent)
                    }
                }
                .labelStyle(.iconOnly)
                .font(.headline)
                .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .accessibilityIdentifier("dropDetail")
    }

    private var doneButton: some View {
        Button {
            withAnimation(motion) { actions.done(drop) }
            dismiss()
        } label: {
            Label("mark done", systemImage: "checkmark").frame(maxWidth: drop.url == nil ? .infinity : nil)
        }
    }

    private var motion: Animation? {
        reduceMotion ? nil : .smooth
    }
}
