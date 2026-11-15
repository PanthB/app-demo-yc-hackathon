#if DEBUG
import os
import SwiftData
import SwiftUI

enum LayoutKind: String, CaseIterable, Identifiable {
    case web, orbit, map

    var id: String { rawValue }

    var name: String {
        switch self {
        case .web: "web"
        case .orbit: "time dial"
        case .map: "night map"
        }
    }

    var symbol: String {
        switch self {
        case .web: "point.3.connected.trianglepath.dotted"
        case .orbit: "clock"
        case .map: "map"
        }
    }

    static var requested: LayoutKind? {
        UserDefaults.standard.string(forKey: "LayoutLab").flatMap(LayoutKind.init(rawValue:))
    }
}

struct LayoutLab: View {
    @Query(sort: \Drop.createdAt, order: .reverse) private var allDrops: [Drop]
    @Environment(\.modelContext) private var context
    @State var kind: LayoutKind
    @State private var board = UserDefaults.standard.string(forKey: "LayoutBoard")
    @State private var path: [UUID] = []
    @Namespace private var namespace

    var body: some View {
        let personal = DeviceIdentity.boardId
        let current = board ?? personal
        let drops = allDrops.filter { NightBoardView.board(of: $0, personal: personal) == current }
        let choices = NightBoardView.boards(in: allDrops, personal: personal)
        let palette = NightPalette.forBoard(current, personal: current == personal)

        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                Menu {
                    ForEach(choices) { choice in
                        Button(choice.name) { withAnimation(.smooth(duration: 0.4)) { board = choice.id } }
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(choices.first { $0.id == current }?.name ?? "my board")
                            .font(NightStyle.pageTitle)
                        Image(systemName: "chevron.down").font(.headline.weight(.bold)).foregroundStyle(NightStyle.tertiary)
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                Group {
                    switch kind {
                    case .web: ConstellationView(drops: drops, namespace: namespace, open: show)
                    case .orbit: OrbitView(drops: drops, namespace: namespace, open: show)
                    case .map: NightMapView(drops: drops, namespace: namespace, open: show)
                    }
                }
                .id("\(kind.rawValue)-\(current)")
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background { NightBackdrop(palette: palette) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("layout", selection: $kind.animation(.smooth(duration: 0.4))) {
                            ForEach(LayoutKind.allCases) { kind in
                                Label(kind.name, systemImage: kind.symbol).tag(kind)
                            }
                        }
                    } label: {
                        Image(systemName: kind.symbol)
                    }
                    .accessibilityIdentifier("layoutMenu")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let drop = allDrops.first(where: { $0.id == id }) {
                    NightDetail(drop: drop, palette: palette)
                        .navigationTransition(.zoom(sourceID: id, in: namespace))
                }
            }
        }
        .tint(palette.ember)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("layoutLab")
        .task {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: "LayoutArrivals") != nil else { return }
            await LayoutReplay.play(context, keep: defaults.integer(forKey: "LayoutArrivals"), cadence: max(defaults.double(forKey: "LayoutCadence"), 0.6))
        }
    }

    private func show(_ drop: Drop) {
        path.append(drop.id)
    }
}

enum LayoutReplay {
    private static let order = [1, 4, 6, 11, 2, 7, 12, 9, 3, 13, 8, 14, 5, 10, 15]

    private struct Read {
        let title: String?
        let artist: String?
        let clusterId: String?
        let clusterLabel: String?
        let neighbors: [DropNeighbor]
    }

    @MainActor
    static func play(_ context: ModelContext, keep: Int, cadence: Double) async {
        var crew: [UUID: Drop] = [:]
        for _ in 0..<20 where crew.isEmpty {
            try? await Task.sleep(for: .milliseconds(300))
            let all = (try? context.fetch(FetchDescriptor<Drop>())) ?? []
            crew = Dictionary(all.filter { $0.boardId == SeedBoard.crewBoardId }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        let queue = order.compactMap { crew[SeedBoard.clientId(board: 2, $0)] }
        var reads: [UUID: Read] = [:]
        for (index, drop) in queue.enumerated() where index >= keep {
            reads[drop.id] = Read(title: drop.title, artist: drop.artist, clusterId: drop.clusterId, clusterLabel: drop.clusterLabel, neighbors: drop.neighbors)
            drop.boardId = "layout-replay"
        }
        save(context)
        try? await Task.sleep(for: .seconds(1.2))
        for (index, drop) in queue.enumerated() where index >= keep {
            guard let read = reads[drop.id] else { continue }
            drop.boardId = SeedBoard.crewBoardId
            drop.createdAt = .now
            drop.status = .pending
            drop.title = nil
            drop.artist = nil
            drop.clusterId = nil
            drop.clusterLabel = nil
            drop.neighbors = []
            save(context)
            Logger.app.info("layout replay: \(drop.authorLabel, privacy: .public) shared something")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                drop.title = read.title
                drop.artist = read.artist
                drop.clusterId = read.clusterId
                drop.clusterLabel = read.clusterLabel
                drop.neighbors = read.neighbors
                drop.status = .processed
                save(context)
            }
            try? await Task.sleep(for: .seconds(cadence))
        }
    }

    @MainActor
    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Logger.store.error("saving the layout replay failed: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
