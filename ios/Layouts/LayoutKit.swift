import SwiftUI

struct LayoutLink: Identifiable, Hashable, Sendable {
    let first: UUID
    let second: UUID
    let reason: String
    var isTrail = false

    var id: String {
        [first.uuidString, second.uuidString].sorted().joined(separator: "|")
    }

    func touches(_ id: UUID?) -> Bool {
        id == first || id == second
    }

    func other(than id: UUID) -> UUID {
        id == first ? second : first
    }

    static func strings(_ drops: [Drop]) -> [LayoutLink] {
        ClusterSnapshot(drops: drops).pairs.map { LayoutLink(first: $0.first, second: $0.second, reason: $0.reason) }
    }

    static func trail(_ ids: [UUID], reason: String) -> [LayoutLink] {
        zip(ids, ids.dropFirst()).map { LayoutLink(first: $0, second: $1, reason: reason, isTrail: true) }
    }
}

enum LayoutMotion {
    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0)
    }

    static func arrive(_ reduceMotion: Bool, delay: Double) -> Animation {
        reduceMotion ? .easeOut(duration: 0.25) : .spring(duration: 0.7, bounce: 0.18).delay(delay)
    }

    static func select(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.3)
    }
}

extension Drop {
    var layoutTitle: String {
        cardTitle(beside: .plain) ?? CardWords.clean(rawText) ?? kind.word
    }

    var personColor: Color {
        NightAvatar(name: authorLabel, colorName: authorColor, personId: authorId).color
    }

    var hasPlace: Bool {
        latitude != nil && longitude != nil
    }
}

struct LayoutBadge: View {
    let drop: Drop
    var size: CGFloat = 52
    var showsKind = true

    @Environment(BoardClock.self) private var clock

    var body: some View {
        let shape = Self.shape(for: drop.kind, size: size)
        art
            .frame(width: size * shape.widthRatio, height: size)
            .clipShape(shape)
            .overlay {
                if drop.kind == .song {
                    Circle().fill(NightStyle.ink).frame(width: size * 0.16, height: size * 0.16)
                        .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5) }
                }
            }
            .overlay { shape.strokeBorder(drop.personColor, lineWidth: max(1.5, size * 0.04)) }
            .overlay(alignment: .bottomTrailing) {
                if showsKind && size >= 34 {
                    Image(systemName: drop.kind.symbol)
                        .font(.system(size: size * 0.2, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: size * 0.38, height: size * 0.38)
                        .background(NightStyle.ink.opacity(0.82), in: .circle)
                        .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.5) }
                        .offset(x: size * 0.1, y: size * 0.06)
                }
            }
            .overlay(alignment: .topTrailing) {
                if drop.isPinned && size >= 34 {
                    Image(systemName: "pin.fill")
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(NightStyle.ink)
                        .frame(width: size * 0.34, height: size * 0.34)
                        .background(.white, in: .circle)
                        .offset(x: size * 0.1, y: -size * 0.08)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: size * 0.16, y: size * 0.08)
    }

    @ViewBuilder
    private var art: some View {
        switch drop.previewFace(now: clock.now) {
        case .image(let image), .cutout(let image):
            Image(uiImage: image).resizable().scaledToFill()
        default:
            LinearGradient(colors: [drop.personColor.mix(with: NightStyle.surface, by: 0.35), NightStyle.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Image(systemName: drop.kind.symbol)
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
        }
    }

    static func shape(for kind: DropKind, size: CGFloat) -> BadgeShape {
        switch kind {
        case .song: BadgeShape(corner: size / 2, widthRatio: 1)
        case .video: BadgeShape(corner: size * 0.2, widthRatio: 0.78)
        case .place: BadgeShape(corner: size * 0.26, widthRatio: 1)
        default: BadgeShape(corner: size * 0.32, widthRatio: 1)
        }
    }
}

struct BadgeShape: InsettableShape {
    var corner: CGFloat
    var widthRatio: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: max(corner - inset, 0), style: .continuous).path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> BadgeShape {
        BadgeShape(corner: corner, widthRatio: widthRatio, inset: inset + amount)
    }
}

struct LayoutFocusPanel: View {
    let drop: Drop
    var lines: [String] = []
    var namespace: Namespace.ID?
    let open: () -> Void
    let close: () -> Void

    @Environment(\.dropActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let isDone = drop.boardZone(now: now) == .done
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: open) {
                    thumbnail
                }
                .buttonStyle(NightPressStyle())
                .accessibilityLabel("open \(drop.layoutTitle)")
                VStack(alignment: .leading, spacing: 3) {
                    Label(drop.kind.word, systemImage: drop.kind.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightStyle.secondary)
                    Text(drop.layoutTitle)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let meta = drop.cardMeta(now: now, beside: .plain) {
                        Text(meta).font(.footnote).foregroundStyle(NightStyle.secondary).monospacedDigit().lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        NightAvatar(name: drop.authorLabel, colorName: drop.authorColor, personId: drop.authorId, size: 18)
                        Text("\(drop.authorLabel) saved this.").font(.footnote).foregroundStyle(NightStyle.secondary).lineLimit(1)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark").font(.footnote.weight(.bold)).frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("close")
            }
            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.footnote)
                    .foregroundStyle(.tint)
                    .lineLimit(2)
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if isDone {
                        Text("marked done.").font(.subheadline).foregroundStyle(NightStyle.secondary)
                        Spacer(minLength: 0)
                        if drop.canUndoMove {
                            Button("put it back", systemImage: "arrow.uturn.backward") {
                                withAnimation(LayoutMotion.settle(reduceMotion)) { actions.undo(drop) }
                            }
                            .buttonStyle(.glass)
                        }
                    } else {
                        Button(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin") {
                            withAnimation(LayoutMotion.settle(reduceMotion)) { actions.pin(drop, !drop.isPinned) }
                        }
                        .buttonStyle(.glass)
                        Button("done", systemImage: "checkmark") {
                            withAnimation(LayoutMotion.settle(reduceMotion)) { actions.done(drop) }
                        }
                        .buttonStyle(.glass)
                        Spacer(minLength: 0)
                        Button("open", systemImage: "arrow.up.left.and.arrow.down.right", action: open)
                            .buttonStyle(.glassProminent)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(14)
        .background(NightStyle.surface, in: .rect(cornerRadius: NightStyle.cardRadius, style: .continuous))
        .overlay { NightStyle.card.strokeBorder(NightStyle.hairline, lineWidth: 1) }
        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        .sensoryFeedback(.impact(weight: .light), trigger: drop.isPinned)
        .sensoryFeedback(.success, trigger: isDone)
        .accessibilityIdentifier("layoutPanel")
    }

    @ViewBuilder
    private var thumbnail: some View {
        let badge = LayoutBadge(drop: drop, size: 64, showsKind: false)
        if let namespace {
            badge.matchedTransitionSource(id: drop.id, in: namespace)
        } else {
            badge
        }
    }
}

struct LayoutLegend: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(NightStyle.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("layoutLegend")
    }
}
