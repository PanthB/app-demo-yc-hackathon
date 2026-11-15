import SwiftUI

struct CardsView: View {
    let sections: [DropSection]
    let namespace: Namespace.ID
    let select: (Drop) -> Void

    @State private var showsDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    switch section.style {
                    case .pinned:
                        header(section)
                        if typeSize.isAccessibilitySize { grid(section.drops) } else { pinnedRow(section.drops) }
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
        .scrollEdgeEffectStyle(.hard, for: .top)
        .overlay {
            if sections.isEmpty { EmptyBoard() }
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
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(showsDone ? "open" : "closed")
        .accessibilityIdentifier("section-\(section.id)")
    }

    private func grid(_ drops: [Drop]) -> some View {
        MasonryLayout(columns: typeSize.isAccessibilitySize ? 1 : 2, spacing: 12) {
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
        .contextMenu { DropMenu(drop: drop) }
        .matchedTransitionSource(id: drop.id, in: namespace) { source in
            source.clipShape(DropCard.shape)
        }
        .matchedGeometryEffect(id: drop.id, in: namespace)
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
