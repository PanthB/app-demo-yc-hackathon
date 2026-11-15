import SwiftUI
import UIKit

struct NightPalette: Equatable, Sendable {
    let colors: [Color]
    let ember: Color

    static let astral = NightPalette(colors: [
        Color(red: 0.07, green: 0.16, blue: 0.62), Color(red: 0.20, green: 0.10, blue: 0.52), Color(red: 0.02, green: 0.30, blue: 0.70),
        Color(red: 0.02, green: 0.06, blue: 0.20), Color(red: 0.05, green: 0.06, blue: 0.16), Color(red: 0.10, green: 0.04, blue: 0.22),
        NightStyle.ink, Color(red: 0.03, green: 0.05, blue: 0.13), NightStyle.ink,
    ], ember: Color(red: 0.45, green: 0.62, blue: 1.0))

    static let temporal = NightPalette(colors: [
        Color(red: 0.95, green: 0.38, blue: 0.12), Color(red: 0.55, green: 0.12, blue: 0.20), Color(red: 0.03, green: 0.38, blue: 0.40),
        Color(red: 0.22, green: 0.06, blue: 0.06), Color(red: 0.06, green: 0.05, blue: 0.08), Color(red: 0.02, green: 0.16, blue: 0.18),
        NightStyle.ink, Color(red: 0.10, green: 0.04, blue: 0.05), NightStyle.ink,
    ], ember: Color(red: 1.0, green: 0.55, blue: 0.28))

    static let prism = NightPalette(colors: [
        Color(red: 0.62, green: 0.10, blue: 0.48), Color(red: 0.10, green: 0.20, blue: 0.75), Color(red: 0.95, green: 0.55, blue: 0.15),
        Color(red: 0.14, green: 0.04, blue: 0.18), Color(red: 0.05, green: 0.05, blue: 0.09), Color(red: 0.02, green: 0.20, blue: 0.16),
        NightStyle.ink, Color(red: 0.05, green: 0.04, blue: 0.12), NightStyle.ink,
    ], ember: Color(red: 1.0, green: 0.45, blue: 0.75))

    static func forBoard(_ boardId: String, personal: Bool) -> NightPalette {
        if personal { return .temporal }
        let others: [NightPalette] = [.astral, .prism]
        return others[PersonMark.colorIndex(for: boardId, count: others.count)]
    }
}

struct NightBackdrop: View {
    var palette: NightPalette = .astral
    var isLiving = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !isLiving)) { context in
            MeshGradient(
                width: 3,
                height: 3,
                points: Self.points(at: reduceMotion || !isLiving ? 0 : context.date.timeIntervalSinceReferenceDate),
                colors: palette.colors,
                smoothsColors: true
            )
        }
        .overlay { NightGrain(opacity: 0.16) }
        .background(NightStyle.ink)
        .animation(.smooth(duration: 1.2), value: palette)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        func wave(_ period: Double, _ phase: Double = 0) -> Float {
            Float(sin(time * 2 * .pi / period + phase))
        }
        return [
            [0, 0], [0.5 + 0.10 * wave(37), 0], [1, 0],
            [0, 0.38 + 0.06 * wave(43, 1)], [0.5 + 0.12 * wave(31, 2), 0.42 + 0.08 * wave(47)], [1, 0.36 + 0.06 * wave(41, 3)],
            [0, 1], [0.5 + 0.08 * wave(53, 4), 1], [1, 1],
        ]
    }
}

struct NightGrain: View {
    var opacity: Double = 0.16
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(decorative: Self.noise, scale: max(displayScale / 1.5, 1))
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    static let noise: CGImage = {
        let side = 160
        var random = StableRandom(UUID(uuid: (7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7)))
        var pixels = [UInt8](repeating: 0, count: side * side)
        for index in pixels.indices {
            pixels[index] = UInt8(random.value(in: 0...255))
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }()
}

#Preview {
    NightBackdrop()
}
