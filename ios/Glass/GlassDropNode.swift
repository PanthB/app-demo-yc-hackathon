import SwiftUI

extension Drop {
    var glassIsSettled: Bool {
        status == .processed && !zoneUnsure
    }

    var glassManualPoint: CGPoint? {
        guard zoneSetByUser, let x = manualX, let y = manualY, (0...1).contains(x), (0...1).contains(y) else { return nil }
        return CGPoint(x: x, y: y)
    }

    var glassSoonest: Date {
        dueAt ?? startsAt ?? .distantFuture
    }

    func glassFrontLabel(now: Date) -> GlassCopy.FrontLabel? {
        GlassCopy.frontLabel(dueAt: dueAt, startsAt: startsAt, whenLabel: whenLabel, now: now)
    }

    func glassSummary(now: Date) -> String {
        let name = GlassCopy.kindName(objectKind, isReminder: dueAt != nil)
        let title = (self.title ?? GlassCopy.rawSummary(text: rawText, url: url)).lowercased()
        let when = GlassCopy.spoken(glassFrontLabel(now: now), now: now)
        return [name, title, GlassCopy.zoneLabel(zone), when].compactMap { $0 }.joined(separator: ", ")
    }
}

struct GlassDropNode: View {
    let drop: Drop
    let placement: GlassLayout.Placement
    let now: Date
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let nearness = placement.nearness
        let width = placement.size.width * placement.scale
        let height = placement.size.height * placement.scale
        let glow: Double = drop.zone == .now && drop.glassIsSettled ? 1 : 0

        object(showsText: nearness > 0.5)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.45), radius: 4 + 8 * nearness, y: 3 + 6 * nearness)
            .shadow(color: GlassCues.now.opacity(0.45 * glow), radius: 18)
            .shadow(color: GlassCues.now.opacity(0.2 * glow), radius: 40)
            .background(alignment: .top) { reflection }
            .colorMultiply(Color(white: 0.42 + 0.58 * nearness))
            .overlay { if !drop.glassIsSettled { GlassCues.Unsure() } }
            .overlay(alignment: .bottom) {
                if drop.zoneSetByUser { GlassCues.HandPlaced().offset(y: 11) }
            }
            .overlay(alignment: .topTrailing) { chip }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(drop.glassSummary(now: now))
            .accessibilityIdentifier("drop.\(GlassCopy.shortTitle(drop.title ?? drop.rawText, limit: 2) ?? drop.objectKind.rawValue)")
            .accessibilitySortPriority(Double(nearness))
    }

    private func object(showsText: Bool) -> some View {
        GlassObjectView(drop: drop, now: now, showsText: showsText, showsDate: placement.scale * 17 >= 12)
            .scaleEffect(placement.scale)
            .rotationEffect(.degrees(placement.tilt))
    }

    @ViewBuilder private var reflection: some View {
        if placement.nearness > 0.6, !reduceTransparency {
            let height = placement.size.height * placement.scale
            object(showsText: false)
                .frame(width: placement.size.width * placement.scale, height: height)
                .scaleEffect(x: 1, y: -1)
                .mask { LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center) }
                .opacity(0.18 * placement.nearness)
                .blur(radius: 2)
                .offset(y: height + 4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var chip: some View {
        let facesItsTime = drop.objectKind == .stub || (drop.objectKind == .sticky && drop.dueAt != nil)
        if placement.nearness > 0.5, drop.glassIsSettled, !facesItsTime, let label = drop.glassFrontLabel(now: now) {
            GlassChip(label: label, now: now)
                .offset(x: GlassLayout.chipOverhang, y: -14)
        }
    }
}

struct GlassChip: View {
    let label: GlassCopy.FrontLabel
    let now: Date

    var body: some View {
        content
            .font(GlassTheme.mono())
            .foregroundStyle(GlassTheme.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder private var content: some View {
        switch label {
        case .countdown(let due): GlassCountdown(due: due, now: now)
        case .time(let text), .phrase(let text): Text(text)
        }
    }
}

struct GlassLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GlassTheme.sentence())
            .foregroundStyle(GlassTheme.text)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 28)
            .accessibilityIdentifier("glassLine")
    }
}
