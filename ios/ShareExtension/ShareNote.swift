import SwiftUI

struct ShareNote: View {
    @ObservedObject var state: ShareState
    var close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasLanded: Bool {
        state.outcome != nil || state.isTakingAWhile
    }

    private var line: String {
        switch state.outcome {
        case .none: "hang on, i'm grabbing it."
        case .dropped: "dropped it,\ni'll find it a spot."
        case .failed: "i couldn't hold on to that one, so please try sharing it again."
        }
    }

    var body: some View {
        ZStack {
            Cork()
            Text(line)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Sunny.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 26)
                .padding(.top, 44)
                .padding(.bottom, 34)
                .frame(maxWidth: 290)
                .background(Sunny.paper, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(alignment: .top) {
                    Pin()
                        .phaseAnimator([1.0, 0.9, 1.0], trigger: state.outcome) { pin, squash in
                            pin.scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
                        } animation: { _ in
                            .spring(response: 0.25, dampingFraction: 0.5)
                        }
                        .offset(y: -9)
                }
                .shadow(color: Sunny.ink.opacity(hasLanded ? 0.2 : 0.3), radius: hasLanded ? 9 : 26, y: hasLanded ? 6 : 22)
                .rotationEffect(.degrees(hasLanded ? -2 : -9))
                .scaleEffect(hasLanded || reduceMotion ? 1 : 1.08)
                .offset(y: hasLanded || reduceMotion ? -30 : -560)
                .opacity(hasLanded ? 1 : 0)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.65), value: hasLanded)
                .accessibilityLabel(line.replacingOccurrences(of: "\n", with: " "))
                .accessibilityIdentifier("shareConfirmation")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state.outcome != nil { close() }
        }
    }
}

private enum Sunny {
    static let board = Color(red: 0.918, green: 0.851, blue: 0.745)
    static let paper = Color(red: 1, green: 0.984, blue: 0.949)
    static let ink = Color(red: 0.169, green: 0.141, blue: 0.125)
    static let tomato = Color(red: 1, green: 0.42, blue: 0.29)
}

private struct Cork: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5EED
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / 2147483648
            }
            for _ in 0..<520 {
                let side = 1 + next() * 2.4
                let speck = CGRect(x: next() * size.width, y: next() * size.height, width: side, height: side)
                context.fill(Path(ellipseIn: speck), with: .color(Sunny.ink.opacity(0.06)))
            }
        }
        .background(Sunny.board)
        .overlay(LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .top, endPoint: .center))
        .ignoresSafeArea()
    }
}

private struct Pin: View {
    var body: some View {
        Circle()
            .fill(Sunny.tomato)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .offset(x: 5, y: 4)
            }
            .frame(width: 22, height: 22)
            .shadow(color: Sunny.ink.opacity(0.3), radius: 2, y: 2)
    }
}
