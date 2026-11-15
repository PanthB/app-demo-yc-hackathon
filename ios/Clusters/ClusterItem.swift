import SwiftUI

struct ClusterShape {
    static let faceScale: CGFloat = 0.85
    static let captionHeight: CGFloat = 26
    static let captionSpacing: CGFloat = 8
    static let minWidth: CGFloat = 128
    static let disc: CGFloat = 102
    static let stripOverlap: CGFloat = 8

    let native: CGSize
    let face: CGSize
    let stripHeight: CGFloat

    init(_ drop: Drop) {
        if drop.objectKind == .record, !drop.showsRawThing {
            native = CGSize(width: 120, height: 120)
            let words = CGFloat((drop.title ?? "").count) * 7.4
            stripHeight = words > Self.minWidth - 20 ? 48 : 30
            face = CGSize(width: Self.minWidth, height: Self.disc - Self.stripOverlap + stripHeight)
        } else {
            native = CorkboardLayout.size(for: drop)
            face = CGSize(width: (native.width * Self.faceScale).rounded(), height: (native.height * Self.faceScale).rounded())
            stripHeight = 0
        }
    }

    var size: CGSize {
        CGSize(width: max(face.width, Self.minWidth), height: face.height + Self.captionSpacing + Self.captionHeight)
    }
}

struct ClusterItem: View {
    let drop: Drop
    let shape: ClusterShape
    let clusterLabel: String?
    let reasons: [String]
    let namespace: Namespace.ID
    let morphs: Bool
    let select: (Drop) -> Void

    @Environment(\.mood) private var mood
    @Environment(\.dropActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardClock.self) private var clock

    var body: some View {
        let now = clock.now
        let preview = drop.previewFace(now: now)
        let meta = drop.cardMeta(now: now, beside: preview)
        VStack(spacing: ClusterShape.captionSpacing) {
            Button {
                select(drop)
            } label: {
                face
                    .frame(width: shape.face.width, height: shape.face.height)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                KindPill(kind: drop.kind)
                    .padding(.leading, 8)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) { fastener }
            .contextMenu { menu }
            .matchedTransitionSource(id: drop.id, in: namespace)
            .modifier(Morph(id: drop.id, namespace: namespace, active: morphs))
            caption(meta ?? drop.authorLabel)
        }
        .frame(width: shape.size.width, height: shape.size.height, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(meta: meta, preview: preview))
        .accessibilityValue(reasons.joined(separator: " "))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { select(drop) }
        .accessibilityIdentifier("clusterDrop-\(drop.kind.word)")
    }

    @ViewBuilder
    private var face: some View {
        if drop.objectKind == .record, !drop.showsRawThing {
            VStack(spacing: -ClusterShape.stripOverlap) {
                PaperObject(drop: drop, size: shape.native)
                    .scaleEffect(ClusterShape.faceScale)
                    .frame(width: ClusterShape.disc, height: ClusterShape.disc)
                Text(drop.title?.lowercased() ?? "")
                    .font(mood.ui(14, weight: .semibold))
                    .foregroundStyle(mood.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(shape.stripHeight > 30 ? 2 : 1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 10)
                    .frame(width: shape.face.width, height: shape.stripHeight)
                    .background(mood.paper, in: RoundedRectangle(cornerRadius: 3))
                    .contactShadow(mood)
            }
        } else {
            PaperObject(drop: drop, size: shape.native)
                .scaleEffect(ClusterShape.faceScale)
                .frame(width: shape.face.width, height: shape.face.height)
        }
    }

    @ViewBuilder
    private var fastener: some View {
        if drop.isPinned {
            PinHead().offset(y: -3)
        } else {
            TapeStrip(seed: drop.id).offset(y: -9)
        }
    }

    private func caption(_ text: String) -> some View {
        HStack(spacing: 6) {
            PersonAvatar(drop: drop)
            Text(text)
                .font(mood.ui(13, weight: .medium))
                .foregroundStyle(mood.quietInk)
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 9)
        .frame(height: ClusterShape.captionHeight)
        .background(mood.paper, in: RoundedRectangle(cornerRadius: 4))
        .contactShadow(mood)
        .frame(maxWidth: shape.size.width)
    }

    @ViewBuilder
    private var menu: some View {
        Button(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin") {
            withAnimation(reduceMotion ? nil : .smooth) { actions.pin(drop, !drop.isPinned) }
        }
        if drop.zone != .done {
            Button("mark done", systemImage: "checkmark.circle") {
                withAnimation(reduceMotion ? nil : .smooth) { actions.done(drop) }
            }
        }
        if drop.canUndoMove {
            Button("put it back", systemImage: "arrow.uturn.backward") {
                withAnimation(reduceMotion ? nil : .smooth) { actions.undo(drop) }
            }
        }
        if drop.url != nil {
            Button("open link", systemImage: "arrow.up.right") {
                actions.open(drop)
            }
        }
    }

    private func spoken(meta: String?, preview: PreviewFace) -> String {
        [
            drop.kind.word,
            drop.cardTitle(beside: preview) ?? preview.words,
            meta,
            "saved by \(drop.authorLabel)",
            drop.isPinned ? "pinned" : clusterLabel.map { "in \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private struct Morph: ViewModifier {
        let id: UUID
        let namespace: Namespace.ID
        let active: Bool

        func body(content: Content) -> some View {
            if active {
                content.matchedGeometryEffect(id: id, in: namespace)
            } else {
                content
            }
        }
    }
}

struct ClusterLabelSlip: View {
    @Environment(\.mood) private var mood
    let text: String

    var body: some View {
        Text(text)
            .font(mood.hand(26))
            .fontWeight(.bold)
            .foregroundStyle(mood.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(height: ClusterLayout.labelHeight)
            .background(mood.paper)
            .contactShadow(mood)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ClusterReasonNote: View {
    @Environment(\.mood) private var mood
    let text: String

    var body: some View {
        Text(text)
            .font(mood.hand(22))
            .fontWeight(.semibold)
            .foregroundStyle(mood.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 240)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(mood.paper)
            .paperShadow()
    }
}

struct ClusterString: Shape {
    let link: ClusterLayout.Link

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: link.from)
        path.addQuadCurve(to: link.to, control: link.control)
        return path
    }
}

struct ClusterStringHitArea: Shape {
    let link: ClusterLayout.Link

    func path(in rect: CGRect) -> Path {
        ClusterString(link: link).path(in: rect).strokedPath(StrokeStyle(lineWidth: 44, lineCap: .round))
    }
}

struct ArcFlight: ViewModifier, Animatable {
    var progress: Double
    let bulge: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let lift = progress * (1 - progress)
        content.offset(x: bulge.width * lift, y: bulge.height * lift)
    }
}
