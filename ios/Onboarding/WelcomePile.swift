import SwiftUI

/// The welcome's hero: drops from sf crew of five kinds (a song, a link, a place, a photo and a clip) land one by one
/// on a loose pile, each with its kind pill, and a small note under the pile's corner says where they went.
struct WelcomePile: View {
    let dealt: Bool
    let shown: Bool
    let dimmed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Slot {
        let kind: DropKind
        let sample: GuideSample?
        let width: CGFloat
        let x: CGFloat
        let y: CGFloat
        let tilt: Double
    }

    private let slots: [Slot] = [
        Slot(kind: .song, sample: .song, width: 124, x: -58, y: -98, tilt: -7),
        Slot(kind: .link, sample: nil, width: 148, x: 62, y: -68, tilt: 6),
        Slot(kind: .place, sample: .ramen, width: 146, x: -52, y: -33, tilt: 4),
        Slot(kind: .photo, sample: .bridge, width: 112, x: 64, y: 22, tilt: -5),
        Slot(kind: .video, sample: .clip, width: 110, x: -6, y: 64, tilt: 3),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                Group {
                    if let sample = slot.sample {
                        GuideTile(sample: sample, width: slot.width)
                    } else {
                        PageTile(width: slot.width)
                    }
                }
                .overlay(alignment: .topLeading) {
                    NightKindTag(kind: slot.kind).padding(10)
                }
                    .scaleEffect(dealt ? (shown ? 1 : 0.94) : 1.08)
                    .rotationEffect(.degrees(dealt ? slot.tilt : slot.tilt + 14))
                    .offset(x: dealt ? slot.x : slot.x + 150, y: dealt ? slot.y : slot.y - 240)
                    .opacity(dealt && shown ? 1 : 0)
                    .blur(radius: shown ? 0 : 10)
                    .animation(motion(delay: Double(index) * 0.1), value: dealt)
                    .animation(leave, value: shown)
            }
            DroppedNote()
                .offset(x: -58, y: 164)
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

private struct PageTile: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text("the best tacos in the mission")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text("timeout.com")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(14)
        .frame(width: width, height: width * 0.75, alignment: .leading)
        .background(Color(red: 0.16, green: 0.17, blue: 0.26), in: .rect(cornerRadius: width * 0.2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: width * 0.2, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
        .environment(\.colorScheme, .dark)
    }
}
