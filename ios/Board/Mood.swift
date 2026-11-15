import SwiftUI
import UIKit

struct Mood {
    let board: Color
    let paper: Color
    let stickerWhite: Color
    let ink: Color
    let person: Color
    let personDeep: Color
    let butter: Color
    let sky: Color
    let mint: Color
    let lilac: Color
    let shade: Color
    let speckle: Double
    let tilt: ClosedRange<Double>
    let land: Animation
    let move: Animation
    var handwriting = true

    var quietInk: Color { ink.opacity(0.7) }

    func hand(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        handwriting
            ? .custom(Self.handFontName, size: size, relativeTo: style)
            : .system(size: (size * 0.75).rounded(), weight: .semibold, design: .rounded)
    }

    func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let handFontName = UIFont.fontNames(forFamilyName: "Caveat").first ?? "Caveat"
    static let handwritingKey = "Handwriting"

    static let sunny = Mood(
        board: Color(hex: 0xEAD9BE),
        paper: Color(hex: 0xFFFBF2),
        stickerWhite: Color(hex: 0xFFFEFA),
        ink: Color(hex: 0x2B2420),
        person: Color(hex: 0xFF6B4A),
        personDeep: Color(hex: 0xC9472B),
        butter: Color(hex: 0xFFD25C),
        sky: Color(hex: 0x7CC4FF),
        mint: Color(hex: 0x8FDDB0),
        lilac: Color(hex: 0xBFA2FF),
        shade: Color(hex: 0x5B3A21),
        speckle: 0.14,
        tilt: -2...2,
        land: .spring(response: 0.45, dampingFraction: 0.65),
        move: .spring(response: 0.55, dampingFraction: 0.8)
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension EnvironmentValues {
    @Entry var mood: Mood = .sunny
}

private struct PaperShadow: ViewModifier {
    @Environment(\.mood) private var mood
    var lifted = false

    func body(content: Content) -> some View {
        if lifted {
            content.shadow(color: mood.shade.opacity(0.22), radius: 18, y: 14)
        } else {
            content
                .shadow(color: mood.shade.opacity(0.3), radius: 3, y: 2)
                .shadow(color: mood.shade.opacity(0.12), radius: 10, y: 6)
        }
    }
}

extension View {
    func paperShadow(lifted: Bool = false) -> some View {
        modifier(PaperShadow(lifted: lifted))
    }

    func contactShadow(_ mood: Mood) -> some View {
        shadow(color: mood.shade.opacity(0.35), radius: 1.5, y: 1.5)
    }
}
