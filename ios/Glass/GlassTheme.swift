import SwiftUI

enum GlassTheme {
    static let base = Color(red: 0.039, green: 0.039, blue: 0.059)
    static let coral = Color(red: 1.0, green: 0.353, blue: 0.235)
    static let pink = Color(red: 1.0, green: 0.239, blue: 0.545)
    static let plum = Color(red: 0.267, green: 0.055, blue: 0.165)
    static let amber = Color(red: 1.0, green: 0.71, blue: 0.278)
    static let sky = Color(red: 0.498, green: 0.89, blue: 1.0)
    static let mint = Color(red: 0.561, green: 0.867, blue: 0.69)
    static let lilac = Color(red: 0.749, green: 0.635, blue: 1.0)
    static let link = Color(red: 1.0, green: 0.561, blue: 0.694)

    static let text = Color.white.opacity(0.96)
    static let softText = Color.white.opacity(0.6)
    static let onWhite = base

    static let land = Animation.spring(response: 0.45, dampingFraction: 0.65)
    static let forward = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let morph = Animation.spring(response: 0.5, dampingFraction: 0.78)
    static let lift = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let fade = Animation.easeInOut(duration: 0.2)

    static func sentence(_ weight: Font.Weight = .semibold) -> Font {
        .system(.subheadline, design: .default, weight: weight)
    }

    static func mono(_ weight: Font.Weight = .medium) -> Font {
        .system(.subheadline, design: .monospaced, weight: weight)
    }
}
