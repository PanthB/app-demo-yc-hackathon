import SwiftUI

struct CardsView: View {
    let sections: [GlassSection]
    let namespace: Namespace.ID
    let select: (Drop) -> Void

    @State private var showsDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private func header(_ section: GlassSection) -> some View {
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

    private func doneHeader(_ section: GlassSection) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth) { showsDone.toggle() }
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
                card(drop)
            }
        }
        .padding(.horizontal, 16)
    }

    private func pinnedRow(_ drops: [Drop]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(drops) { drop in
                    card(drop, pictureRatio: 0.6)
                        .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 12)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private func card(_ drop: Drop, pictureRatio: CGFloat? = nil) -> some View {
        Button {
            select(drop)
        } label: {
            DropCard(drop: drop, pictureRatio: pictureRatio)
        }
        .buttonStyle(CardPressStyle())
        .matchedTransitionSource(id: drop.id, in: namespace)
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
