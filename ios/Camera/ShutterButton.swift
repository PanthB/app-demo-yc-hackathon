import SwiftUI

struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
            Circle()
                .fill(.white)
                .padding(8)
        }
        .frame(width: 78, height: 78)
        .contentShape(Circle())
        .scaleEffect(configuration.isPressed ? 0.92 : 1)
        .opacity(configuration.isPressed ? 0.9 : 1)
        .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}
