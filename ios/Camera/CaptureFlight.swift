import SwiftUI

struct CaptureFlight: View {
    let shot: CameraShot
    let start: CGRect
    let end: CGRect
    let reduceMotion: Bool
    let onLand: () -> Void

    @State private var isFlying = false
    @State private var isFaded = false

    static let lift = 0.3
    static let fall = 0.45
    static let cardAspect: CGFloat = 4 / 5
    static let landedCorner: CGFloat = 12
    static let landedBorder: CGFloat = 2

    private struct Pose {
        var width: CGFloat
        var height: CGFloat
        var x: CGFloat
        var y: CGFloat
        var rotation: Double = 0
        var corner: CGFloat = 0
        var border: CGFloat = 0
        var lift: CGFloat = 0
    }

    var body: some View {
        Group {
            if reduceMotion {
                photo(width: start.width, height: start.height, corner: 0, border: 0)
                    .position(x: start.midX, y: start.midY)
                    .opacity(isFaded ? 0 : 1)
            } else {
                flight
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) { isFaded = true }
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                isFlying = true
                try? await Task.sleep(for: .seconds(Self.lift + Self.fall))
            }
            onLand()
        }
    }

    private var flight: some View {
        let cardWidth = start.width * 0.62
        let cardHeight = cardWidth / Self.cardAspect
        let cardY = start.midY - 40
        return Color.clear.keyframeAnimator(
            initialValue: Pose(width: start.width, height: start.height, x: start.midX, y: start.midY),
            trigger: isFlying
        ) { _, pose in
            photo(width: pose.width, height: pose.height, corner: pose.corner, border: pose.border)
                .shadow(color: .black.opacity(0.4 * pose.lift), radius: 24 * pose.lift, y: 16 * pose.lift)
                .rotationEffect(.degrees(pose.rotation))
                .position(x: pose.x, y: pose.y)
        } keyframes: { _ in
            KeyframeTrack(\.width) {
                LinearKeyframe(cardWidth, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(end.width, duration: Self.fall, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.height) {
                LinearKeyframe(cardHeight, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(end.height, duration: Self.fall, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.x) {
                LinearKeyframe(start.midX, duration: Self.lift)
                LinearKeyframe(end.midX, duration: Self.fall, timingCurve: .easeOut)
            }
            KeyframeTrack(\.y) {
                LinearKeyframe(cardY, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(end.midY, duration: Self.fall, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.rotation) {
                LinearKeyframe(-4, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(0, duration: 0.25, timingCurve: .easeOut)
            }
            KeyframeTrack(\.corner) {
                LinearKeyframe(26, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(Self.landedCorner, duration: Self.fall, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.border) {
                LinearKeyframe(5, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(Self.landedBorder, duration: Self.fall, timingCurve: .easeInOut)
            }
            KeyframeTrack(\.lift) {
                LinearKeyframe(1, duration: Self.lift, timingCurve: .easeOut)
                LinearKeyframe(0, duration: Self.fall, timingCurve: .easeInOut)
            }
        }
    }

    private func photo(width: CGFloat, height: CGFloat, corner: CGFloat, border: CGFloat) -> some View {
        Image(uiImage: shot.image)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white, lineWidth: border)
            }
    }
}
