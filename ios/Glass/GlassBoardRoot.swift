import SwiftData
import SwiftUI

struct GlassBoardRoot: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @Environment(BoardClock.self) private var clock
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            CardsView(
                sections: DropSection.build(drops, filter: .everyone, me: DeviceIdentity.personId, now: clock.now),
                namespace: namespace
            ) { _ in }
            .navigationTitle(drops.first.map { $0.boardId.replacingOccurrences(of: "-", with: " ") } ?? "my board")
        }
        .tint(Color(red: 1.0, green: 0.42, blue: 0.29))
    }
}
