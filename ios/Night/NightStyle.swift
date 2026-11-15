import CoreImage
import SwiftUI
import UIKit

enum NightStyle {
    static let ink = Color(red: 0.027, green: 0.027, blue: 0.043)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let hairline = Color.white.opacity(0.08)
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.4)
    static let flame = Color(red: 1.0, green: 0.52, blue: 0.16)

    static let cardRadius: CGFloat = 24
    static let card = RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    static let margin: CGFloat = 20
    static let gutter: CGFloat = 12
    static let inset: CGFloat = 12
    static let avatar: CGFloat = 24
    static let pillHeight: CGFloat = 24
    static let target: CGFloat = 44

    static let pageTitle = Font.largeTitle.bold()
    static let heading = Font.title3.weight(.semibold)
    static let itemTitle = Font.headline
    static let body = Font.subheadline
    static let caption = Font.caption.weight(.semibold)
    static let symbolWeight = Font.Weight.semibold

    static func motion(_ reduceMotion: Bool, _ animation: Animation = .smooth(duration: 0.35)) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : animation
    }
}

struct NightPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NightStyle.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(minHeight: NightStyle.target)
            .padding(.horizontal, 16)
            .background(.white, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
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
        let tone = UIColor(hue: hue, saturation: min(saturation, 0.6), brightness: min(max(brightness * 0.35, 0.1), 0.22), alpha: 1)
        cache.setObject(tone, forKey: key as NSString)
        return Color(uiColor: tone)
    }
}
