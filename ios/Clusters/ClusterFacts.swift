import Foundation

struct ClusterFacts: Equatable {
    struct Neighbor: Equatable {
        var clientId: String
        var reason: String
    }

    var vibes: [String] = []
    var clusterId: String?
    var clusterLabel: String?
    var neighbors: [Neighbor] = []
    var genre: String?

    init(
        vibes: [String] = [],
        clusterId: String? = nil,
        clusterLabel: String? = nil,
        neighbors: [Neighbor] = [],
        genre: String? = nil
    ) {
        self.vibes = vibes
        self.clusterId = clusterId
        self.clusterLabel = clusterLabel
        self.neighbors = neighbors
        self.genre = genre
    }

    init(_ drop: Drop) {
        #if DEBUG
        if drop.status == .processed, let facts = ClusterFixture.facts[drop.id] {
            self = facts
            return
        }
        #endif
        self.init()
    }
}
