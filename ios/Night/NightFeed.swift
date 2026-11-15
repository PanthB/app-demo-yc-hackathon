import SwiftUI

struct NightFeed: View {
    let sections: [DropSection]
    let namespace: Namespace.ID
    let select: (Drop) -> Void

    @State private var showsDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions
    @Environment(BoardClock.self) private var clock

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                switch section.style {
                case .pinned:
                    header(section)
                    pinnedRow(section.drops)
                case .zone:
                    header(section)
                    zone(section.drops)
                case .done:
                    doneHeader(section)
                    if showsDone {
                        grid(section.drops).saturation(0.2).opacity(0.75)
                    }
                }
            }
        }
    }

    private func header(_ section: DropSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(section.title).font(NightStyle.sectionTitle)
            Text("\(section.drops.count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(NightStyle.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("section-\(section.id)")
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 12)
    }

    private func doneHeader(_ section: DropSection) -> some View {
        Button {
            withAnimation(NightStyle.motion(reduceMotion)) { showsDone.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title).font(NightStyle.sectionTitle)
                Text("\(section.drops.count)").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(NightStyle.tertiary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightStyle.secondary)
                    .rotationEffect(.degrees(showsDone ? 90 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(showsDone ? "open" : "closed")
        .accessibilityIdentifier("section-\(section.id)")
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func zone(_ drops: [Drop]) -> some View {
        let leadsWide = drops.count % 2 == 1
        VStack(spacing: 12) {
            if leadsWide, let first = drops.first {
                item(first) { NightCard(drop: first, wide: true) }
            }
            if drops.count > 1 || !leadsWide {
                grid(Array(drops.dropFirst(leadsWide ? 1 : 0)))
            }
        }
        .padding(.horizontal, 16)
    }

    private func grid(_ drops: [Drop]) -> some View {
        MasonryLayout(columns: 2, spacing: 12) {
            ForEach(drops) { drop in
                item(drop) { NightCard(drop: drop) }
            }
        }
    }

    private func pinnedRow(_ drops: [Drop]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(drops) { drop in
                    item(drop) { NightCard(drop: drop, wide: true) }
                        .containerRelativeFrame(.horizontal, count: drops.count == 1 ? 1 : 7, span: drops.count == 1 ? 1 : 6, spacing: 12)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card.scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.94)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func item(_ drop: Drop, @ViewBuilder label: () -> some View) -> some View {
        Button {
            select(drop)
        } label: {
            label()
        }
        .buttonStyle(NightPressStyle())
        .contextMenu { NightDropMenu(drop: drop) }
        .matchedTransitionSource(id: drop.id, in: namespace) { source in
            source.clipShape(NightStyle.card)
        }
    }
}

struct NightDropMenu: View {
    let drop: Drop
    @Environment(\.dropActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardClock.self) private var clock

    var body: some View {
        Button(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin") {
            withAnimation(NightStyle.motion(reduceMotion)) { actions.pin(drop, !drop.isPinned) }
        }
        if drop.zone != .done {
            Button("mark done", systemImage: "checkmark.circle") {
                withAnimation(NightStyle.motion(reduceMotion)) { actions.done(drop) }
            }
        }
        if drop.canUndoMove {
            Button("put it back", systemImage: "arrow.uturn.backward") {
                withAnimation(NightStyle.motion(reduceMotion)) { actions.undo(drop) }
            }
        }
        Menu("move to", systemImage: "arrow.right") {
            let current = drop.boardZone(now: clock.now)
            ForEach(Zone.allCases.filter { $0 != .done && $0 != current }, id: \.self) { zone in
                Button(zone.displayName) {
                    withAnimation(NightStyle.motion(reduceMotion)) { actions.move(drop, zone) }
                }
            }
        }
        if drop.url != nil {
            Button("open link", systemImage: "arrow.up.right") { actions.open(drop) }
        }
    }
}

struct NightPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
