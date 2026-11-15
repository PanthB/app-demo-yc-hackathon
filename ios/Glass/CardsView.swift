import SwiftUI

struct CardsView: View {
    let sections: [DropSection]
    let namespace: Namespace.ID
    let select: (Drop) -> Void

    @State private var showsDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions
    @Environment(BoardClock.self) private var clock

    var body: some View {
        ScrollView {
            GlassEffectContainer {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        switch section.style {
                        case .pinned:
                            header(section)
                            pinnedRow(section.drops)
                        case .zone:
                            header(section)
                            grid(section.drops)
                        case .done:
                            doneHeader(section)
                            if showsDone { grid(section.drops) }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("cardsView")
    }

    private func header(_ section: DropSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(section.title).font(.title3.weight(.semibold))
            Text("\(section.drops.count)").font(.title3).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("section-\(section.id)")
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func doneHeader(_ section: DropSection) -> some View {
        Button {
            withAnimation(motion) { showsDone.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(section.title).font(.title3.weight(.semibold))
                Text("\(section.drops.count)").font(.title3).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsDone ? 90 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(showsDone ? "open" : "closed")
        .accessibilityIdentifier("section-\(section.id)")
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func grid(_ drops: [Drop]) -> some View {
        MasonryLayout(columns: 2, spacing: 12) {
            ForEach(drops) { drop in
                item(drop) { DropCard(drop: drop) }
            }
        }
        .padding(.horizontal, 16)
    }

    private func pinnedRow(_ drops: [Drop]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(drops) { drop in
                    item(drop) { PinnedCard(drop: drop) }
                        .containerRelativeFrame(.horizontal, count: 4, span: 3, spacing: 12)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private func item(_ drop: Drop, @ViewBuilder label: () -> some View) -> some View {
        Button {
            select(drop)
        } label: {
            label()
        }
        .buttonStyle(CardPressStyle())
        .contextMenu { menu(drop) }
        .matchedTransitionSource(id: drop.id, in: namespace)
        .matchedGeometryEffect(id: drop.id, in: namespace)
    }

    @ViewBuilder
    private func menu(_ drop: Drop) -> some View {
        Button(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin") {
            withAnimation(motion) { actions.pin(drop, !drop.isPinned) }
        }
        if drop.zone != .done {
            Button("mark done", systemImage: "checkmark.circle") {
                withAnimation(motion) { actions.done(drop) }
            }
        }
        if drop.canUndoMove {
            Button("put it back", systemImage: "arrow.uturn.backward") {
                withAnimation(motion) { actions.undo(drop) }
            }
        }
        Menu("move to", systemImage: "arrow.right") {
            let current = drop.boardZone(now: clock.now)
            ForEach(Zone.allCases.filter { $0 != .done && $0 != current }, id: \.self) { zone in
                Button(zone.displayName) {
                    withAnimation(motion) { actions.move(drop, zone) }
                }
            }
        }
        if drop.url != nil {
            Button("open link", systemImage: "arrow.up.right") {
                actions.open(drop)
            }
        }
    }

    private var motion: Animation? {
        reduceMotion ? nil : .smooth
    }
}

private struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}
