import SwiftUI

/// The welcome's hero: drops from sf crew fanned out behind a frosted card, with a pill under them. The tiles
/// tuck under the card's edges so they show through it blurred.
struct WelcomeFan: View {
    let fanned: Bool
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
        Slot(sample: .ramen, width: 92, x: -100, y: 74, tilt: 10),
        Slot(sample: .night, width: 76, x: 2, y: 80, tilt: -3),
        Slot(sample: .bridge, width: 72, x: 102, y: 88, tilt: -11),
        Slot(sample: .song, width: 92, x: -104, y: -72, tilt: -13),
        Slot(sample: .place, width: 108, x: 106, y: -70, tilt: 12),
        Slot(sample: .clip, width: 92, x: 0, y: -92, tilt: 0),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                GuideTile(sample: slot.sample, width: slot.width)
                    .scaleEffect(fanned ? (shown ? 1 : 0.94) : 0.6)
                    .rotationEffect(.degrees(fanned ? slot.tilt : 0))
                    .offset(x: fanned ? slot.x : slot.x * 0.2, y: fanned ? slot.y : 0)
                    .opacity(fanned && shown ? 1 : 0)
                    .blur(radius: shown ? 0 : 10)
                    .animation(motion(delay: Double(index) * 0.05), value: fanned)
                    .animation(leave, value: shown)
            }
            DropCardFrost()
                .scaleEffect(fanned && shown ? 1 : 0.94)
                .opacity(fanned && shown ? 1 : 0)
                .blur(radius: shown ? 0 : 10)
                .animation(motion(delay: 0.18), value: fanned)
                .animation(leave, value: shown)
            Text("songs, places and clips")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 18)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)
                .offset(y: 168)
                .opacity(fanned && shown ? 1 : 0)
                .blur(radius: fanned && shown ? 0 : 6)
                .animation(motion(delay: 0.4), value: fanned)
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
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.74).delay(delay)
    }
}

private struct DropCardFrost: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("dropped it in sf crew.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                HStack(spacing: -7) {
                    ForEach([GuideSample.Person.you, .maya, .sam, .alex], id: \.self) { person in
                        GuideAvatar(person: person, size: 24)
                            .overlay(Circle().stroke(Color(white: 0.16), lineWidth: 2))
                    }
                }
                Text("you and 3 friends")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(.white, in: .circle)
            }
        }
        .padding(18)
        .frame(width: 308, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
        .environment(\.colorScheme, .dark)
    }
}
