import CoreImage
import SwiftUI
import UIKit

enum NightStyle {
    static let ink = Color(red: 0.027, green: 0.027, blue: 0.043)
    static let surface = Color(red: 0.085, green: 0.085, blue: 0.11)
    static let hairline = Color.white.opacity(0.09)
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.4)
    static let cardRadius: CGFloat = 26
    static let card = RoundedRectangle(cornerRadius: cardRadius, style: .continuous)

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static let sectionTitle = Font.system(.title, design: .serif).italic()

    static func motion(_ reduceMotion: Bool, _ animation: Animation = .smooth(duration: 0.35)) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : animation
    }
}

enum NightPlate {
    private static let pairs: [(Color, Color)] = [
        (Color(red: 0.98, green: 0.45, blue: 0.20), Color(red: 0.45, green: 0.08, blue: 0.30)),
        (Color(red: 0.15, green: 0.35, blue: 0.95), Color(red: 0.05, green: 0.08, blue: 0.30)),
        (Color(red: 0.05, green: 0.62, blue: 0.58), Color(red: 0.03, green: 0.14, blue: 0.22)),
        (Color(red: 0.80, green: 0.30, blue: 0.85), Color(red: 0.16, green: 0.06, blue: 0.32)),
        (Color(red: 0.98, green: 0.72, blue: 0.30), Color(red: 0.50, green: 0.16, blue: 0.08)),
    ]

    static func colors(for id: UUID) -> (Color, Color) {
        pairs[PersonMark.colorIndex(for: id.uuidString, count: pairs.count)]
    }
}

struct NightGradientPlate: View {
    let seed: UUID

    var body: some View {
        let (glow, deep) = NightPlate.colors(for: seed)
        var random = StableRandom(seed, salt: 11)
        let center = UnitPoint(x: random.value(in: 0.15...0.85), y: random.value(in: 0.1...0.5))
        RadialGradient(colors: [glow, deep, NightStyle.surface], center: center, startRadius: 4, endRadius: 260)
            .overlay { NightGrain(opacity: 0.22) }
    }
}

enum ArtworkTone {
    private static let cache = NSCache<NSString, UIColor>()
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func color(of image: UIImage, key: String) -> Color {
        if let cached = cache.object(forKey: key as NSString) { return Color(uiColor: cached) }
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]),
              let output = filter.outputImage
        else { return NightStyle.surface }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let average = UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let tone = UIColor(hue: hue, saturation: min(saturation * 1.15, 0.85), brightness: min(max(brightness * 0.42, 0.12), 0.3), alpha: 1)
        cache.setObject(tone, forKey: key as NSString)
        return Color(uiColor: tone)
    }
}
