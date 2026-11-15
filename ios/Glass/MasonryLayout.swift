import SwiftUI

struct MasonryLayout: Layout {
    var columns = 2
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        return CGSize(width: width, height: arrange(subviews, width: width).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let column = Masonry.columnWidth(total: bounds.width, columns: columns, spacing: spacing)
        for (subview, placement) in zip(subviews, arrange(subviews, width: bounds.width).placements) {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(placement.column) * (column + spacing), y: bounds.minY + placement.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: column, height: nil)
            )
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (placements: [Masonry.Placement], height: CGFloat) {
        let column = Masonry.columnWidth(total: width, columns: columns, spacing: spacing)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }
        return Masonry.place(heights: heights, columns: columns, spacing: spacing)
    }
}
