import SwiftUI

struct NightFeed: View {
    let sections: [DropSection]
    let namespace: Namespace.ID
    let select: (Drop) -> Void

    @State private var showsDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions
    @Environment(BoardClock.self) private var clock
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 0) {
                    switch section.style {
                    case .pinned, .zone:
                        header(section)
                        grid(section.drops)
                    case .done:
                        doneHeader(section)
                        if showsDone {
                            grid(section.drops).saturation(0.2).opacity(0.75)
                        }
                    }
                }
                .id(section.id)
            }
        }
    }

    private func header(_ section: DropSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(section.title).font(NightStyle.sectionHeading)
            Text("\(section.drops.count)").font(NightStyle.sectionHeading).monospacedDigit().foregroundStyle(NightStyle.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("section-\(section.id)")
        .padding(.horizontal, NightStyle.margin)
        .padding(.top, 32)
        .padding(.bottom, 12)
    }

    private func doneHeader(_ section: DropSection) -> some View {
        Button {
            withAnimation(NightStyle.motion(reduceMotion)) { showsDone.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title).font(NightStyle.sectionHeading)
                Text("\(section.drops.count)").font(NightStyle.sectionHeading).monospacedDigit().foregroundStyle(NightStyle.tertiary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(NightStyle.body.weight(NightStyle.symbolWeight))
                    .foregroundStyle(NightStyle.secondary)
                    .rotationEffect(.degrees(showsDone ? 90 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(showsDone ? "open" : "closed")
        .accessibilityIdentifier("section-\(section.id)")
        .padding(.horizontal, NightStyle.margin)
        .padding(.top, 32)
        .padding(.bottom, 12)
    }

    private func grid(_ drops: [Drop]) -> some View {
        MasonryLayout(columns: typeSize.isAccessibilitySize ? 1 : 2, spacing: NightStyle.gutter) {
            ForEach(drops) { drop in
                item(drop) { NightCard(drop: drop) }
            }
        }
        .padding(.horizontal, NightStyle.margin)
    }

    private func item(_ drop: Drop, @ViewBuilder label: () -> some View) -> some View {
        Button {
            select(drop)
        } label: {
            label()
        }
        .buttonStyle(NightPressStyle())
        .id(drop.id)
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
