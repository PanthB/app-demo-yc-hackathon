import SwiftUI

struct GlassBackdrop: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 4,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.48), .init(1, 0.5),
                .init(0, 0.84), .init(0.45, 0.86), .init(1, 0.82),
                .init(0, 1), .init(0.5, 1), .init(1, 1),
            ],
            colors: [
                GlassTheme.base, GlassTheme.base, GlassTheme.base,
                Color(red: 0.07, green: 0.035, blue: 0.07), Color(red: 0.12, green: 0.04, blue: 0.09), Color(red: 0.07, green: 0.035, blue: 0.08),
                Color(red: 0.79, green: 0.28, blue: 0.2), Color(red: 0.71, green: 0.21, blue: 0.29), Color(red: 0.75, green: 0.19, blue: 0.42),
                Color(red: 0.23, green: 0.06, blue: 0.11), GlassTheme.plum, Color(red: 0.23, green: 0.055, blue: 0.15),
            ]
        )
        .background(GlassTheme.base)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
