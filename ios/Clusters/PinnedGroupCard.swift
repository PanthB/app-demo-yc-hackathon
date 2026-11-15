import SwiftData
import SwiftUI

struct PinnedGroupCard: View {
    let boardId: String

    @Query(sort: \Drop.createdAt, order: .reverse) private var drops: [Drop]
    @Environment(BoardsStore.self) private var boards
    @Environment(BoardClock.self) private var clock
    @AppStorage private var chosen: String
    @Namespace private var zoom
    @State private var opened = false

    private static let shown = 6

    init(boardId: String) {
        self.boardId = boardId
        _chosen = AppStorage(wrappedValue: "", "PinnedGroup-\(boardId)")
    }

    var body: some View {
        let shared = boards.boards.first { $0.boardId == boardId }?.shared ?? false
        let onBoard = drops.filter { $0.boardId == boardId || (!shared && $0.boardId.isEmpty) }
        let snapshot = ClusterSnapshot(drops: onBoard)
        let groups = snapshot.groups.filter { $0.shelf == .cluster }
        let byId = Dictionary(onBoard.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newest = { (group: ClusterSnapshot.Group) in group.members.compactMap { byId[$0]?.createdAt }.max() ?? .distantPast }
        if onBoard.count >= 3, let group = groups.first(where: { $0.id == chosen }) ?? groups.max(by: { newest($0) < newest($1) }) {
            let members = group.members.compactMap { byId[$0] }
            Button {
                opened = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(group.label).font(.title3.weight(.semibold)).lineLimit(1)
                        Text("\(members.count)").font(.title3).foregroundStyle(.secondary).monospacedDigit()
                    }
                    PinnedGroupSpace(
                        drops: Array(members.prefix(Self.shown)),
                        offsets: ClusterField(snapshot, size: CGSize(width: 1, height: 1)).offsets,
                        now: clock.now
                    )
                    .frame(height: 200)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                .contentShape(.rect(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: group.id, in: zoom)
            .contextMenu {
                Menu("show another group", systemImage: "square.stack") {
                    ForEach(groups) { other in
                        Button(other.label) { chosen = other.id }
                    }
                }
            }
            .fullScreenCover(isPresented: $opened) {
                PinnedGroupBoard(label: group.label, drops: members)
                    .navigationTransition(.zoom(sourceID: group.id, in: zoom))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(group.label), \(members.count) drops")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { opened = true }
            .accessibilityIdentifier("pinnedGroupCard")
        }
    }
}

private struct PinnedGroupSpace: View {
    let drops: [Drop]
    let offsets: [UUID: CGVector]
    let now: Date

    var body: some View {
        GeometryReader { proxy in
            let placed = drops.compactMap { drop in offsets[drop.id].map { (drop, CGPoint(x: $0.dx, y: $0.dy)) } }
            let xs = placed.map(\.1.x)
            let ys = placed.map(\.1.y)
            let middle = CGPoint(x: ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2, y: ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2)
            let reach = CGSize(width: max(((xs.max() ?? 0) - (xs.min() ?? 0)) / 2, 1), height: max(((ys.max() ?? 0) - (ys.min() ?? 0)) / 2, 1))
            let side: CGFloat = 52
            let scale = CGSize(
                width: min(1, (proxy.size.width / 2 - side / 2) / reach.width),
                height: min(1, (proxy.size.height / 2 - side / 2) / reach.height)
            )
            ForEach(placed, id: \.0.id) { item in
                DropThumbnail(face: item.0.previewFace(now: now), kind: item.0.kind, seed: item.0.id, side: side, radius: 12)
                    .position(
                        x: proxy.size.width / 2 + (item.1.x - middle.x) * scale.width,
                        y: proxy.size.height / 2 + (item.1.y - middle.y) * scale.height
                    )
            }
        }
    }
}

private struct PinnedGroupBoard: View {
    let label: String
    let drops: [Drop]

    @Environment(\.dismiss) private var dismiss
    @Namespace private var namespace
    @State private var path: [Drop] = []

    var body: some View {
        NavigationStack(path: $path) {
            ClusterBoardView(drops: drops, namespace: namespace) { path.append($0) }
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) { dismiss() }
                    }
                }
                .navigationDestination(for: Drop.self) { drop in
                    DropDetailView(drop: drop)
                        .navigationTransition(.zoom(sourceID: drop.id, in: namespace))
                }
        }
    }
}
