import Foundation

enum Masonry {
    struct Placement: Equatable {
        let column: Int
        let y: CGFloat
    }

    static let balancedLimit = 12

    static func columnWidth(total: CGFloat, columns: Int, spacing: CGFloat) -> CGFloat {
        guard columns > 0 else { return 0 }
        return max((total - spacing * CGFloat(columns - 1)) / CGFloat(columns), 0)
    }

    static func place(heights: [CGFloat], columns: Int, spacing: CGFloat) -> (placements: [Placement], height: CGFloat) {
        guard columns > 0 else { return ([], 0) }
        var best = stack(heights, into: shortestFirst(heights, columns: columns, spacing: spacing), columns: columns, spacing: spacing)
        guard columns == 2, (3...balancedLimit).contains(heights.count) else { return best }
        for mask in 0..<(1 << (heights.count - 1)) {
            let split = heights.indices.map { $0 == 0 ? 0 : (mask >> ($0 - 1)) & 1 }
            let candidate = stack(heights, into: split, columns: columns, spacing: spacing)
            if candidate.height < best.height - 0.5 { best = candidate }
        }
        return best
    }

    private static func shortestFirst(_ heights: [CGFloat], columns: Int, spacing: CGFloat) -> [Int] {
        var next = Array(repeating: CGFloat(0), count: columns)
        return heights.map { height in
            let column = next.indices.min { next[$0] < next[$1] } ?? 0
            next[column] += height + spacing
            return column
        }
    }

    private static func stack(_ heights: [CGFloat], into split: [Int], columns: Int, spacing: CGFloat) -> (placements: [Placement], height: CGFloat) {
        var next = Array(repeating: CGFloat(0), count: columns)
        var placements: [Placement] = []
        for (height, column) in zip(heights, split) {
            placements.append(Placement(column: column, y: next[column]))
            next[column] += height + spacing
        }
        return (placements, max((next.max() ?? 0) - spacing, 0))
    }
}
