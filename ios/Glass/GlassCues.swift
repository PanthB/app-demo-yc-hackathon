import SwiftUI

enum GlassCues {
    static let now = GlassTheme.coral
    static let nearby = GlassTheme.sky
    static let done = GlassTheme.mint
    static let vibes = GlassTheme.lilac
    static let joined = GlassTheme.link

    struct HandPlaced: View {
        var body: some View {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
    }

    struct Unsure: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .padding(-8)
                .accessibilityHidden(true)
        }
    }

    struct DoneTick: View {
        var body: some View {
            Group {
                if let tick = GlassKit.image("done-tick") {
                    tick
                } else {
                    Circle()
                        .fill(GlassTheme.mint)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Path { path in
                                path.move(to: CGPoint(x: 5.8, y: 10.4))
                                path.addLine(to: CGPoint(x: 8.8, y: 13.4))
                                path.addLine(to: CGPoint(x: 14.4, y: 6.8))
                            }
                            .stroke(GlassKit.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                }
            }
            .accessibilityHidden(true)
        }
    }

    struct Link: View {
        let from: CGPoint
        let to: CGPoint

        var body: some View {
            let line = Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            ZStack {
                line.stroke(GlassTheme.link.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .blur(radius: 6)
                line.stroke(GlassTheme.link, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    struct VibesHaze: View {
        var body: some View {
            Ellipse()
                .fill(
                    EllipticalGradient(
                        colors: [GlassTheme.lilac.opacity(0.24), GlassTheme.lilac.opacity(0)],
                        center: .center,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.5
                    )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
