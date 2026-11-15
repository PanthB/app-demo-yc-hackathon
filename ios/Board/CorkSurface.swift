import SwiftUI

struct CorkSurface: View {
    @Environment(\.mood) private var mood

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(mood.board))
            var random = StableRandom(UUID(uuid: (0xC0, 0x4B, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)))
            let count = Int(size.width * size.height / 70)
            for _ in 0..<count {
                let x = random.value(in: 0...Double(size.width))
                let y = random.value(in: 0...Double(size.height))
                let radius = random.value(in: 0.35...1.25)
                let dark = random.value(in: 0...1) < 0.7
                let strength = random.value(in: 0.4...1) * mood.speckle * (dark ? 1 : 1.6)
                let color = dark ? mood.ink.opacity(strength) : Color.white.opacity(strength)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(color))
            }
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
