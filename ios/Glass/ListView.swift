import SwiftUI

struct ListView: View {
    let sections: [DropSection]
    let namespace: Namespace.ID
    let select: (Drop) -> Void

    @State private var showsDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dropActions) private var actions

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    if section.style != .done || showsDone {
                        ForEach(section.drops) { drop in
                            row(drop)
                        }
                    }
                } header: {
                    if section.style == .done {
                        doneHeader(section)
                    } else {
                        header(section)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("section-\(section.id)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(8)
        .accessibilityIdentifier("listView")
    }

    private func header(_ section: DropSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(section.title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
            Text("\(section.drops.count)").font(.title3).foregroundStyle(.secondary).monospacedDigit()
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    private func doneHeader(_ section: DropSection) -> some View {
        Button {
            withAnimation(motion) { showsDone.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                header(section)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsDone ? 90 : 0))
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(showsDone ? "open" : "closed")
        .accessibilityIdentifier("section-\(section.id)")
    }

    private func row(_ drop: Drop) -> some View {
        Button {
            select(drop)
        } label: {
            DropRow(drop: drop).foregroundStyle(.primary)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .swipeActions(edge: .leading) {
            Button(drop.isPinned ? "unpin" : "pin", systemImage: drop.isPinned ? "pin.slash" : "pin") {
                withAnimation(motion) { actions.pin(drop, !drop.isPinned) }
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            if drop.zone != .done {
                Button("mark done", systemImage: "checkmark") {
                    withAnimation(motion) { actions.done(drop) }
                }
                .tint(.green)
            }
        }
        .contextMenu { DropMenu(drop: drop) }
        .matchedTransitionSource(id: drop.id, in: namespace)
        .matchedGeometryEffect(id: drop.id, in: namespace)
        .accessibilityIdentifier("dropRow")
    }

    private var motion: Animation? {
        reduceMotion ? nil : .smooth
    }
}
