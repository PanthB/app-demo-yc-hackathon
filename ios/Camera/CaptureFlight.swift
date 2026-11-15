import SwiftUI

struct CaptureFlight: View {
    let shot: CameraShot
    let frame: CGRect
    let target: CGPoint
    let reduceMotion: Bool
    let onLand: () -> Void
    let onDone: () -> Void

    @State private var isFlying = false
    @State private var isFaded = false

    static let landsAfter: Duration = .milliseconds(820)
    static let endsAfter: Duration = .milliseconds(980)

    private struct Pose {
        var scale: CGFloat = 1
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rotation: Double = 0
        var shape: CGFloat = 0
        var corner: CGFloat = 0
        var lift: CGFloat = 0
        var opacity: Double = 1
    }

    private var cardScale: CGFloat { 0.6 }

    private var landScale: CGFloat {
        34 / max(frame.width, 1)
    }

    private var photoAspect: CGFloat {
        let size = shot.image.size
        guard size.width > 0, size.height > 0 else { return 0.75 }
        return size.width / size.height
    }

    var body: some View {
        Group {
            if reduceMotion {
                photo(width: frame.width, height: frame.height, corner: 0, border: 0)
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(isFaded ? 0 : 1)
            } else {
                flight
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3)) { isFaded = true }
            } else {
                isFlying = true
            }
            try? await Task.sleep(for: reduceMotion ? .milliseconds(120) : Self.landsAfter)
            onLand()
            try? await Task.sleep(for: reduceMotion ? .milliseconds(240) : Self.endsAfter - Self.landsAfter)
            onDone()
        }
    }

    private var flight: some View {
        let dx = target.x - frame.midX
        let dy = target.y - frame.midY
        return Color.clear.keyframeAnimator(initialValue: Pose(), trigger: isFlying) { _, pose in
            let height = frame.height + (frame.width / photoAspect - frame.height) * pose.shape
            photo(
                width: frame.width,
                height: height,
                corner: pose.corner / max(pose.scale, 0.01),
                border: 5 * pose.shape / max(pose.scale, 0.01)
            )
            .shadow(color: .black.opacity(0.45 * pose.lift), radius: 30 * pose.lift / max(pose.scale, 0.2), y: 22 * pose.lift / max(pose.scale, 0.2))
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotation))
            .offset(x: pose.x, y: pose.y)
            .opacity(pose.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(cardScale, duration: 0.36, spring: .init(duration: 0.4, bounce: 0.12))
                CubicKeyframe(cardScale * 1.03, duration: 0.14)
                SpringKeyframe(landScale, duration: 0.36, spring: .init(duration: 0.4, bounce: 0))
            }
            KeyframeTrack(\.y) {
                SpringKeyframe(-36, duration: 0.36, spring: .init(duration: 0.4, bounce: 0.1))
                CubicKeyframe(-52, duration: 0.14)
                SpringKeyframe(dy, duration: 0.4, spring: .init(duration: 0.42, bounce: 0.22))
            }
            KeyframeTrack(\.x) {
                CubicKeyframe(0, duration: 0.5)
                SpringKeyframe(dx, duration: 0.36, spring: .init(duration: 0.38, bounce: 0))
            }
            KeyframeTrack(\.rotation) {
                SpringKeyframe(-5, duration: 0.36, spring: .init(duration: 0.4, bounce: 0.2))
                CubicKeyframe(-4, duration: 0.14)
                SpringKeyframe(8, duration: 0.22, spring: .snappy)
                SpringKeyframe(0, duration: 0.2, spring: .bouncy)
            }
            KeyframeTrack(\.shape) {
                SpringKeyframe(1, duration: 0.36, spring: .init(duration: 0.36, bounce: 0))
            }
            KeyframeTrack(\.corner) {
                CubicKeyframe(30, duration: 0.3)
                CubicKeyframe(30, duration: 0.3)
                CubicKeyframe(7, duration: 0.2)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(1, duration: 0.36)
                CubicKeyframe(1, duration: 0.24)
                CubicKeyframe(0.25, duration: 0.22)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.8)
                LinearKeyframe(0, duration: 0.1)
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
