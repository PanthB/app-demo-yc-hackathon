import SwiftData
import SwiftUI

struct GlassBoardRoot: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @AppStorage(ViewMode.storageKey) private var storedView: String?
    @Environment(BoardClock.self) private var clock
    @Namespace private var namespace
    @State private var selected: Drop?

    var body: some View {
        let sections = DropSection.build(drops, filter: .everyone, me: DeviceIdentity.personId, now: clock.now)
        NavigationStack {
            Group {
                if ViewMode.resolve(stored: storedView) == .list {
                    ListView(sections: sections, namespace: namespace) { selected = $0 }
                } else {
                    CardsView(sections: sections, namespace: namespace) { selected = $0 }
                }
            }
            .navigationTitle(drops.first.map { $0.boardId.replacingOccurrences(of: "-", with: " ") } ?? "my board")
        }
        .sheet(item: $selected) { drop in
            DropDetailView(drop: drop)
                .navigationTransition(.zoom(sourceID: drop.id, in: namespace))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .tint(Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 0.42, blue: 0.29, alpha: 1)
                : UIColor(red: 0.79, green: 0.28, blue: 0.17, alpha: 1)
        }))
    }
}
