import SwiftUI

struct CorkSurface: View {
    @Environment(\.mood) private var mood

    var body: some View {
        mood.board
            .overlay {
                Image("Kit/cork-speckle")
                    .resizable(resizingMode: .tile)
                    .foregroundStyle(mood.ink.opacity(mood.speckle))
            }
            .overlay {
                LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
            }
            .accessibilityHidden(true)
    }
}
