import SwiftUI

struct GlassBackdrop: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 4,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.52), .init(0.5, 0.5), .init(1, 0.52),
                .init(0, 0.8), .init(0.45, 0.82), .init(1, 0.78),
                .init(0, 1), .init(0.5, 1), .init(1, 1),
            ],
            colors: [
                GlassTheme.base, GlassTheme.base, GlassTheme.base,
                Color(red: 0.07, green: 0.035, blue: 0.07), Color(red: 0.12, green: 0.04, blue: 0.09), Color(red: 0.07, green: 0.035, blue: 0.08),
                Color(red: 0.74, green: 0.26, blue: 0.18), Color(red: 0.66, green: 0.2, blue: 0.27), Color(red: 0.7, green: 0.18, blue: 0.39),
                Color(red: 0.14, green: 0.04, blue: 0.08), Color(red: 0.17, green: 0.04, blue: 0.1), Color(red: 0.14, green: 0.04, blue: 0.1),
            ]
        )
        .background(GlassTheme.base)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
