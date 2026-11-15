#if DEBUG
import os
import SwiftData
import SwiftUI

enum ClusterFixture {
    static let arrivalId = UUID(uuidString: "C1057E00-0000-4000-8000-000000000001") ?? UUID()
    static let copies = max(1, UserDefaults.standard.integer(forKey: "ClusterDebugCopies"))

    @MainActor
    static func fill(_ context: ModelContext, now: Date = .now) {
        SeedBoard.pin(into: context, now: now)
        guard copies > 1 else { return }
        let crew = ((try? context.fetch(FetchDescriptor<Drop>())) ?? []).filter { $0.boardId == SeedBoard.crewBoardId }
        for copy in 1..<copies {
            for seed in crew {
                let drop = Drop(id: copyId(seed.id, copy), createdAt: seed.createdAt.addingTimeInterval(-Double(copy) * 37 * 60), authorId: seed.authorId, boardId: seed.boardId, sourceKind: seed.sourceKind, url: seed.url)
                drop.authorName = seed.authorName
                drop.authorColor = seed.authorColor
                drop.title = seed.title
                drop.artist = seed.artist
                drop.placeName = seed.placeName
                drop.latitude = seed.latitude
                drop.longitude = seed.longitude
                drop.type = seed.type
                drop.objectKind = seed.objectKind
                drop.thumbnailPath = seed.thumbnailPath
                drop.mediaDuration = seed.mediaDuration
                drop.status = .processed
                drop.vibes = seed.vibes
                drop.clusterId = seed.clusterId
                drop.clusterLabel = seed.clusterLabel
                drop.neighbors = seed.neighbors.map { neighbor in
                    DropNeighbor(clientId: UUID(uuidString: neighbor.clientId).map { copyId($0, copy).uuidString } ?? neighbor.clientId, reason: neighbor.reason)
                }
                drop.applyDecidedZone(seed.zone, unsure: false)
                context.insert(drop)
            }
        }
        save(context)
    }

    @MainActor
    static func playArrival(_ context: ModelContext) async {
        try? await Task.sleep(for: .seconds(2.5))
        let drop = Drop(id: arrivalId, createdAt: .now, authorId: SeedBoard.panth.id, boardId: SeedBoard.crewBoardId, sourceKind: .url, url: "https://open.spotify.com/track/6MpCaSIOfqBqbMED4kXgNY")
        drop.authorName = SeedBoard.panth.name
        drop.authorColor = SeedBoard.panth.color
        context.insert(drop)
        save(context)
        Logger.app.info("cluster fixture: prom queen landed")
        try? await Task.sleep(for: .seconds(1.8))
        drop.title = "prom queen"
        drop.artist = "beach bunny"
        drop.type = .song
        drop.objectKind = .record
        drop.status = .processed
        drop.genre = "indie"
        drop.vibes = ["upbeat", "indie", "steady"]
        drop.clusterId = "sunny-afternoons"
        drop.clusterLabel = "upbeat, in the mission"
        drop.neighbors = [
            DropNeighbor(clientId: SeedBoard.clientId(board: 2, 4).uuidString, reason: "both upbeat, steady."),
            DropNeighbor(clientId: SeedBoard.clientId(board: 2, 5).uuidString, reason: "both upbeat."),
        ]
        drop.applyDecidedZone(.vibes, unsure: false)
        save(context)
        Logger.app.info("cluster fixture: prom queen was read")
    }

    private static func copyId(_ id: UUID, _ copy: Int) -> UUID {
        let text = id.uuidString
        return UUID(uuidString: String(format: "%04X", 0x100 * copy) + text.dropFirst(4)) ?? UUID()
    }

    @MainActor
    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Logger.store.error("saving the cluster fixture failed: \(String(describing: error), privacy: .public)")
        }
    }
}

struct ClusterPlayground: View {
    var body: some View {
        ClusterPlaygroundBoard()
            .modelContainer(for: Drop.self, inMemory: true)
    }
}

private struct ClusterPlaygroundBoard: View {
    @Query(sort: \Drop.createdAt) private var drops: [Drop]
    @Environment(\.modelContext) private var context
    @Namespace private var namespace
    @State private var opened: Drop?
    @State private var filled = false

    var body: some View {
        NavigationStack {
            ClusterBoardView(drops: filled ? drops.filter { $0.boardId == SeedBoard.crewBoardId } : [], namespace: namespace, me: SeedBoard.panth.id) { opened = $0 }
                .navigationTitle("sf crew")
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
                .sheet(item: $opened) { drop in
                    Text(drop.title ?? "")
                        .font(.title2.weight(.semibold))
                        .presentationDetents([.medium])
                        .navigationTransition(.zoom(sourceID: drop.id, in: namespace))
                }
        }
        .task {
            ClusterFixture.fill(context)
            filled = true
            if UserDefaults.standard.bool(forKey: "ClusterDebugArrival") {
                await ClusterFixture.playArrival(context)
            }
        }
    }
}
#endif
