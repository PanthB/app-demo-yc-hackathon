import SwiftUI

/// The welcome's hero: drops from sf crew land one by one on a loose pile, like photos tossed on a table, and a
/// small note under the pile's corner says where they went.
struct WelcomePile: View {
    let dealt: Bool
    let shown: Bool
    let dimmed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Slot {
        let sample: GuideSample
        let width: CGFloat
        let x: CGFloat
        let y: CGFloat
        let tilt: Double
    }

    private let slots: [Slot] = [
        Slot(sample: .ramen, width: 160, x: -44, y: 34, tilt: -8),
        Slot(sample: .bridge, width: 126, x: 58, y: -26, tilt: 9),
        Slot(sample: .night, width: 134, x: -50, y: -40, tilt: -4),
        Slot(sample: .song, width: 140, x: 46, y: 40, tilt: 6),
        Slot(sample: .place, width: 168, x: -10, y: 8, tilt: -3),
        Slot(sample: .clip, width: 128, x: 22, y: -14, tilt: 4),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                GuideTile(sample: slot.sample, width: slot.width)
                    .scaleEffect(dealt ? (shown ? 1 : 0.94) : 1.08)
                    .rotationEffect(.degrees(dealt ? slot.tilt : slot.tilt + 14))
                    .offset(x: dealt ? slot.x : slot.x + 150, y: dealt ? slot.y : slot.y - 240)
                    .opacity(dealt && shown ? 1 : 0)
                    .blur(radius: shown ? 0 : 10)
                    .animation(motion(delay: Double(index) * 0.1), value: dealt)
                    .animation(leave, value: shown)
            }
            DroppedNote()
                .offset(x: -58, y: 156)
                .opacity(dealt && shown ? 1 : 0)
                .offset(y: dealt ? 0 : 8)
                .blur(radius: dealt && shown ? 0 : 6)
                .animation(motion(delay: 0.75), value: dealt)
                .animation(leave, value: shown)
        }
        .frame(height: 380)
        .opacity(dimmed ? 0.6 : 1)
        .animation(.smooth(duration: 0.25), value: dimmed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var leave: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : shown ? .spring(response: 0.55, dampingFraction: 0.8) : .smooth(duration: 0.25)
    }

    private func motion(delay: Double) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.78).delay(delay)
    }
}

private struct DroppedNote: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(.white, in: .circle)
            Text("dropped it in sf crew.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: -5) {
                ForEach([GuideSample.Person.maya, .sam, .alex], id: \.self) { person in
                    GuideAvatar(person: person, size: 18)
                        .overlay(Circle().stroke(Color(white: 0.16), lineWidth: 1.5))
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .frame(height: 34)
        .glassEffect(.regular, in: .capsule)
        .environment(\.colorScheme, .dark)
    }
}
