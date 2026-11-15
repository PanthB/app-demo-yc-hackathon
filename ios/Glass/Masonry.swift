import Foundation

enum Masonry {
    struct Placement: Equatable {
        let column: Int
        let y: CGFloat
    }

    static func columnWidth(total: CGFloat, columns: Int, spacing: CGFloat) -> CGFloat {
        guard columns > 0 else { return 0 }
        return max((total - spacing * CGFloat(columns - 1)) / CGFloat(columns), 0)
    }

    static func place(heights: [CGFloat], columns: Int, spacing: CGFloat) -> (placements: [Placement], height: CGFloat) {
        guard columns > 0 else { return ([], 0) }
        var next = Array(repeating: CGFloat(0), count: columns)
        var placements: [Placement] = []
        for height in heights {
            let column = next.indices.min { next[$0] < next[$1] } ?? 0
            placements.append(Placement(column: column, y: next[column]))
            next[column] += height + spacing
        }
        return (placements, max((next.max() ?? 0) - spacing, 0))
    }
}
