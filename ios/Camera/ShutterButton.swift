import SwiftUI

struct ShutterButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.9), lineWidth: 4)
            Circle()
                .fill(.white)
                .padding(9)
                .scaleEffect(configuration.isPressed ? 0.84 : 1)
                .opacity(configuration.isPressed ? 0.85 : 1)
        }
        .frame(width: 80, height: 80)
        .contentShape(Circle())
        .glassEffect(.clear.interactive(), in: .circle)
        .animation(
            configuration.isPressed
                ? .easeOut(duration: 0.12)
                : (reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.4)),
            value: configuration.isPressed
        )
    }
}
