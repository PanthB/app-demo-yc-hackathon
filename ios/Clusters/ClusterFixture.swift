#if DEBUG
import os
import SwiftData
import SwiftUI

enum ClusterFixture {
    static let arrivalId = UUID(uuidString: "C1057E00-0000-4000-8000-000000000001") ?? UUID()
    static let copies = max(1, UserDefaults.standard.integer(forKey: "ClusterDebugCopies"))
    static let live = UserDefaults.standard.bool(forKey: "ClusterDebugLive")

    private typealias Placement = (number: Int, cluster: String, label: String)

    private struct Step {
        let number: Int
        let placements: [Placement]
    }

    private static let upbeat = "upbeat, in the mission"
    private static let golden = "golden hour, by the water"

    private static let liveStart: [Placement] = [
        (5, "sunny-afternoons", "upbeat, outdoors"),
        (1, "sunny-afternoons", "upbeat, outdoors"),
        (11, "golden-hour", "by the water"),
    ]

    private static let liveSteps: [Step] = [
        Step(number: 2, placements: [(2, "mornings", "morning, food")]),
        Step(number: 3, placements: [(2, "mornings", "morning, in the mission"), (3, "mornings", "morning, in the mission")]),
        Step(number: 4, placements: [1, 5, 2, 3, 4].map { ($0, "sunny-afternoons", upbeat) }),
        Step(number: 6, placements: [(6, "sunny-afternoons", upbeat)]),
        Step(number: 7, placements: [(6, "late-night", "late night, food"), (7, "late-night", "late night, food")]),
        Step(number: 8, placements: [6, 7, 8].map { ($0, "late-night", "late night") }),
        Step(number: 12, placements: [11, 12].map { ($0, "golden-hour", golden) }),
        Step(number: 9, placements: [(9, "late-night", "late night")]),
        Step(number: 13, placements: [(13, "golden-hour", golden)]),
        Step(number: 10, placements: [(10, "late-night", "late night")]),
        Step(number: 14, placements: [(14, "golden-hour", golden)]),
        Step(number: 15, placements: [(15, "golden-hour", golden)]),
    ]

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
    static func prepareLive(_ context: ModelContext) -> Set<UUID> {
        let crew = crewDrops(context)
        let start = Dictionary(liveStart.map { (SeedBoard.clientId(board: 2, $0.number), $0) }, uniquingKeysWith: { first, _ in first })
        var hidden = Set<UUID>()
        for drop in crew.values {
            drop.pinnedAt = nil
            if let placement = start[drop.id] {
                place(drop, placement)
            } else {
                hidden.insert(drop.id)
            }
        }
        save(context)
        return hidden
    }

    @MainActor
    static func playLive(_ context: ModelContext, reveal: (UUID) -> Void) async {
        let crew = crewDrops(context)
        try? await Task.sleep(for: .seconds(2))
        for step in liveSteps {
            guard let drop = crew[SeedBoard.clientId(board: 2, step.number)] else { continue }
            drop.createdAt = .now
            drop.status = .pending
            drop.clusterId = nil
            drop.clusterLabel = nil
            save(context)
            reveal(drop.id)
            Logger.app.info("cluster fixture: \(drop.authorName ?? "a friend", privacy: .public) added \(drop.title ?? "a drop", privacy: .public)")
            try? await Task.sleep(for: .seconds(1.4))
            drop.status = .processed
            for placement in step.placements {
                if let member = crew[SeedBoard.clientId(board: 2, placement.number)] { place(member, placement) }
            }
            save(context)
            try? await Task.sleep(for: .seconds(2.4))
        }
        Logger.app.info("cluster fixture: the live drip is done")
    }

    @MainActor
    private static func crewDrops(_ context: ModelContext) -> [UUID: Drop] {
        let crew = ((try? context.fetch(FetchDescriptor<Drop>())) ?? []).filter { $0.boardId == SeedBoard.crewBoardId }
        return Dictionary(crew.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func place(_ drop: Drop, _ placement: Placement) {
        drop.clusterId = placement.cluster
        drop.clusterLabel = placement.label
    }

    @MainActor
    static func playArrival(_ context: ModelContext) async {
        try? await Task.sleep(for: .seconds(2.5))
        let drop = Drop(id: arrivalId, createdAt: .now, authorId: SeedBoard.maya.id, boardId: SeedBoard.crewBoardId, sourceKind: .url, url: "https://open.spotify.com/track/6MpCaSIOfqBqbMED4kXgNY")
        drop.authorName = SeedBoard.maya.name
        drop.authorColor = SeedBoard.maya.color
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
    @State private var hidden: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ClusterBoardView(drops: filled ? drops.filter { $0.boardId == SeedBoard.crewBoardId && !hidden.contains($0.id) } : [], namespace: namespace, me: SeedBoard.panth.id) { opened = $0 }
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
            if ClusterFixture.live { hidden = ClusterFixture.prepareLive(context) }
            filled = true
            if ClusterFixture.live {
                await ClusterFixture.playLive(context) { hidden.remove($0) }
            } else if UserDefaults.standard.bool(forKey: "ClusterDebugArrival") {
                await ClusterFixture.playArrival(context)
            }
        }
    }
}
#endif
