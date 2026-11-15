import SwiftUI

enum GuidePhase: Int {
    case hidden, shareApp, shareSheet, sharedSong, sharedPlace, sharedClip
    case board, addMenu, addedLink
    case cluster, strings, friend

    var inBoard: Bool { rawValue >= GuidePhase.board.rawValue }
    var byVibe: Bool { rawValue >= GuidePhase.cluster.rawValue }
}

enum GuideTarget: Hashable {
    case share, ourApp, plus, pasteLink
}

struct GuideTargetKey: PreferenceKey {
    static let defaultValue: [GuideTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [GuideTarget: Anchor<CGRect>], nextValue: () -> [GuideTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func guideTarget(_ target: GuideTarget) -> some View {
        anchorPreference(key: GuideTargetKey.self, value: .bounds) { [target: $0] }
    }
}

struct GuideHint: Equatable {
    let target: GuideTarget
    /// Where the arrow starts, from the middle of the thing it points at.
    let offset: CGSize
}

/// The phone mockup and the example drops. The phone rises once and stays; each step only changes what's
/// on its screen and where the drops sit, so nothing ever slides in as a whole screen. The phone is taller
/// than the stage and fades out at its foot, behind the words.
struct GuideStage: View {
    let step: GuideStep
    let shared: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BoardLines") private var lines = false
    @State private var phase: GuidePhase = .hidden

    var body: some View {
        GeometryReader { proxy in
            let layout = GuideLayout(size: proxy.size)
            ZStack(alignment: .topLeading) {
                phone(layout)
                if lines {
                    strings(layout)
                }
                ForEach(Array(GuideSample.guide.enumerated()), id: \.element) { index, sample in
                    card(sample, layout)
                        .zIndex(Double(index))
                }
                .environment(\.guideOwnBoard, !shared)
                Group {
                    boardChrome(layout)
                    labels(layout)
                    toast(layout)
                    addMenu(layout)
                }
                .zIndex(10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: layout.clearBottom / max(proxy.size.height, 1)),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlayPreferenceValue(GuideTargetKey.self) { targets in
                GeometryReader { local in
                    ZStack {
                        if let hint, let anchor = targets[hint.target] {
                            GuideArrow(target: local[anchor], hint: hint, bounds: local.size)
                                .id(hint.target)
                                .transition(.asymmetric(
                                    insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.15)),
                                    removal: .opacity.animation(.easeOut(duration: 0.15))
                                ))
                        }
                    }
                    .frame(width: local.size.width, height: local.size.height)
                }
            }
        }
        .task(id: step) { await play(step) }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: phase) { _, new in
            [.sharedSong, .sharedPlace, .sharedClip, .addedLink, .cluster, .friend].contains(new)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: script

    /// Each step plays its example once, in about four seconds. Moving on cancels it, and the next step starts
    /// from its own first beat, so nothing queues.
    private func play(_ step: GuideStep) async {
        let beats: [(GuidePhase, Double)]
        switch step {
        case .welcome: beats = [(.hidden, 0)]
        case .share: beats = [(.shareApp, 0.12), (.shareSheet, 1.3), (.sharedSong, 1.1), (.sharedPlace, 1.0), (.sharedClip, 0.6)]
        case .add: beats = [(.board, 0.05), (.addMenu, 1.3), (.addedLink, 1.2)]
        case .vibes: beats = [(.cluster, 0.05), (.strings, 0.8), (.friend, 1.4)]
        }
        for (next, wait) in beats {
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.86)) {
                phase = next
            }
        }
    }

    private var hint: GuideHint? {
        switch phase {
        case .shareApp: GuideHint(target: .share, offset: CGSize(width: -64, height: 56))
        case .shareSheet: GuideHint(target: .ourApp, offset: CGSize(width: -70, height: -84))
        case .board: GuideHint(target: .plus, offset: CGSize(width: -76, height: -60))
        case .addMenu: GuideHint(target: .pasteLink, offset: CGSize(width: -96, height: -64))
        default: nil
        }
    }

    private var accessibilityText: String {
        switch step {
        case .welcome: ""
        case .share: "a song, a place and a clip get shared from other apps and land on the board."
        case .add: "the plus button adds a photo, a song or a link."
        case .vibes: "the drops gather into groups that feel the same, and a friend's new song joins the right one."
        }
    }

    // MARK: phone

    private func phone(_ layout: GuideLayout) -> some View {
        GuidePhone(width: layout.phoneWidth) {
            GuideScreen(phase: phase, shared: shared, inset: layout.screenInset)
        }
        .position(x: layout.phoneCenter.x, y: layout.phoneCenter.y + (phase == .hidden && !reduceMotion ? 90 : 0))
        .opacity(phase == .hidden ? 0 : 1)
    }

    // MARK: cards

    private struct Pose {
        var center: CGPoint
        var scale: CGFloat = 1
        var tilt: Double = 0
        var opacity: Double = 1
    }

    private func card(_ sample: GuideSample, _ layout: GuideLayout) -> some View {
        let pose = pose(sample, layout)
        let delay = delay(sample)
        let x = reduceMotion ? Animation.easeInOut(duration: 0.25) : .spring(response: 0.62, dampingFraction: 0.8).delay(delay)
        let y = reduceMotion ? Animation.easeInOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.75).delay(delay)
        let settle = reduceMotion ? Animation.easeInOut(duration: 0.25) : .spring(response: 0.45, dampingFraction: 0.7).delay(delay)
        return GuideCard(sample: sample)
            .animation(settle) {
                $0.scaleEffect(pose.scale)
                    .rotationEffect(.degrees(pose.tilt))
                    .opacity(pose.opacity)
            }
            .animation(x) { $0.offset(x: pose.center.x) }
            .animation(y) { $0.offset(y: pose.center.y) }
            .position(x: 0, y: 0)
    }

    private func delay(_ sample: GuideSample) -> Double {
        switch phase {
        case .sharedSong where sample == .song, .sharedPlace where sample == .place, .sharedClip where sample == .clip: 0.25
        case .board: Double([GuideSample.song, .place, .clip].firstIndex(of: sample) ?? 0) * 0.06
        case .cluster: Double(GuideSample.guide.firstIndex(of: sample) ?? 0) * 0.05
        default: 0
        }
    }

    private func pose(_ sample: GuideSample, _ layout: GuideLayout) -> Pose {
        let screen = layout.screen
        let tucked = Pose(center: CGPoint(x: screen.midX, y: screen.minY + 160), scale: 0.3, opacity: 0)
        let reachedBy: [GuidePhase: GuideSample] = [.sharedSong: .song, .sharedPlace: .place, .sharedClip: .clip]

        switch sample {
        case .song, .place, .clip:
            if phase.byVibe { return clusterPose(sample, layout) }
            if phase.inBoard { return gridPose(sample, layout) }
            let order: [GuideSample] = [.song, .place, .clip]
            guard let mine = order.firstIndex(of: sample),
                  let reached = reachedBy[phase].flatMap({ order.firstIndex(of: $0) }),
                  mine <= reached
            else { return tucked }
            return pilePose(sample, layout)
        case .link:
            if phase.byVibe { return clusterPose(sample, layout) }
            if phase == .addedLink { return gridPose(sample, layout) }
            return Pose(center: layout.plusCenter, scale: 0.2, opacity: 0)
        case .night:
            if phase == .friend { return clusterPose(sample, layout) }
            var arriving = clusterPose(sample, layout)
            arriving.center.y -= 60
            arriving.scale *= 0.8
            arriving.opacity = 0
            return arriving
        default:
            if phase.byVibe { return clusterPose(sample, layout) }
            return Pose(center: CGPoint(x: screen.midX, y: layout.clearBottom), scale: 0.4, opacity: 0)
        }
    }

    /// Shared drops land in a small pile on the phone's lower right, and step 2 deals them onto the board.
    private func pilePose(_ sample: GuideSample, _ layout: GuideLayout) -> Pose {
        let scale: CGFloat = 88 / GuideSample.width
        let x = layout.screen.maxX - 32
        let base = layout.clearBottom - 104
        switch sample {
        case .song: return Pose(center: CGPoint(x: x, y: base - 12), scale: scale, tilt: -6)
        case .place: return Pose(center: CGPoint(x: x - 10, y: base + 4), scale: scale, tilt: 4)
        default: return Pose(center: CGPoint(x: x - 4, y: base + 2), scale: scale, tilt: -2)
        }
    }

    private func gridPose(_ sample: GuideSample, _ layout: GuideLayout) -> Pose {
        let screen = layout.screen
        let gap: CGFloat = 8
        let scale = (screen.width - gap * 3) / 2 / GuideSample.width
        let left = screen.minX + gap + GuideSample.width * scale / 2
        let right = screen.maxX - gap - GuideSample.width * scale / 2
        let top = screen.minY + (shared ? 116 : 80)
        switch sample {
        case .song: return Pose(center: CGPoint(x: left, y: top + GuideSample.song.height * scale / 2), scale: scale)
        case .clip: return Pose(center: CGPoint(x: left, y: top + (GuideSample.song.height + gap) * scale + GuideSample.clip.height * scale / 2), scale: scale)
        case .place: return Pose(center: CGPoint(x: right, y: top + GuideSample.place.height * scale / 2), scale: scale)
        default: return Pose(center: CGPoint(x: right, y: top + (GuideSample.place.height + gap) * scale + GuideSample.link.height * scale / 2), scale: scale)
        }
    }

    /// Two loose packs: four sunny drops, then the late-night pair a friend's song completes.
    private func clusterPose(_ sample: GuideSample, _ layout: GuideLayout) -> Pose {
        let s = layout.clusterScale
        let gap: CGFloat = 10
        let width = GuideSample.width * s
        let left = layout.screen.midX - width / 2 - 14
        let right = layout.screen.midX + width / 2 + 14
        let top = layout.sunnyTop
        let late = layout.lateTop
        func half(_ sample: GuideSample) -> CGFloat { sample.height * s / 2 }
        switch sample {
        case .song: return Pose(center: CGPoint(x: left, y: top + half(.song)), scale: s, tilt: -2)
        case .place: return Pose(center: CGPoint(x: right, y: top + 8 + half(.place)), scale: s, tilt: 2)
        case .link: return Pose(center: CGPoint(x: left, y: top + GuideSample.song.height * s + gap + half(.link)), scale: s, tilt: 1.5)
        case .clip: return Pose(center: CGPoint(x: right, y: top + 8 + GuideSample.place.height * s + gap + half(.clip)), scale: s, tilt: -1.5)
        case .night: return Pose(center: CGPoint(x: left, y: late + half(.night)), scale: s, tilt: 1.5)
        default: return Pose(center: CGPoint(x: right, y: late + 6 + half(.ramen)), scale: s, tilt: -2)
        }
    }

    // MARK: strings, labels, chrome

    private func strings(_ layout: GuideLayout) -> some View {
        let sunny: [(GuideSample, GuideSample)] = [(.song, .place), (.song, .link), (.place, .clip)]
        return ZStack {
            Path { path in
                for (a, b) in sunny {
                    path.move(to: clusterPose(a, layout).center)
                    path.addLine(to: clusterPose(b, layout).center)
                }
            }
            .trim(from: 0, to: phase.rawValue >= GuidePhase.strings.rawValue ? 1 : 0)
            .stroke(Color.onboardingTint.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeOut(duration: 0.6), value: phase)
            Path { path in
                path.move(to: clusterPose(.ramen, layout).center)
                path.addLine(to: clusterPose(.night, layout).center)
            }
            .trim(from: 0, to: phase == .friend ? 1 : 0)
            .stroke(Color.onboardingTint.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeOut(duration: 0.5).delay(0.35), value: phase)
        }
        .opacity(phase.byVibe ? 1 : 0)
    }

    private func labels(_ layout: GuideLayout) -> some View {
        ZStack(alignment: .topLeading) {
            GuideSlip(text: "sunny afternoons", tilt: -2)
                .position(x: layout.screen.midX, y: layout.sunnyTop - 16)
            GuideSlip(text: "late night", tilt: 1.5)
                .position(x: layout.screen.midX, y: layout.lateTop - 16)
        }
        .opacity(phase.byVibe ? 1 : 0)
        .scaleEffect(phase.byVibe ? 1 : 0.9)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.7).delay(0.25), value: phase.byVibe)
    }

    private func boardChrome(_ layout: GuideLayout) -> some View {
        GuideBottomBar()
            .environment(\.colorScheme, .dark)
            .frame(width: layout.screen.width - 24)
            .position(x: layout.screen.midX, y: layout.plusCenter.y)
            .opacity(phase.inBoard && !phase.byVibe ? 1 : 0)
            .animation(.smooth(duration: 0.2), value: phase.byVibe)
    }

    private func toast(_ layout: GuideLayout) -> some View {
        let text: String? = switch phase {
        case .sharedSong, .sharedPlace, .sharedClip: shared ? "dropped it in \(Onboarding.demoBoardName)." : "dropped it, i'll find it a spot."
        case .friend: "maya added a song."
        default: nil
        }
        return ZStack {
            if let text {
                HStack(spacing: 6) {
                    if phase == .friend {
                        GuideAvatar(person: .maya, size: 18)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    }
                    Text(text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.black, in: .capsule)
                .transition(.scale(scale: 0.35).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.42, dampingFraction: 0.78), value: text)
        .frame(width: layout.screen.width - 16)
        .position(x: layout.screen.midX, y: layout.screen.minY + 22)
    }

    private func addMenu(_ layout: GuideLayout) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if phase == .addMenu {
                VStack(alignment: .leading, spacing: 0) {
                    menuRow("photo", symbol: "photo", target: nil)
                    Divider()
                    menuRow("paste link", symbol: "link", target: .pasteLink)
                    Divider()
                    menuRow("note", symbol: "note.text", target: nil)
                }
                .frame(width: 150)
                .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
                .transition(.scale(scale: 0.4, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .frame(width: 150, height: 130, alignment: .bottomTrailing)
        .position(x: layout.plusCenter.x - 58, y: layout.plusCenter.y - 90)
    }

    private func menuRow(_ title: String, symbol: String, target: GuideTarget?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: symbol)
        }
        .font(.system(size: 14, weight: target == nil ? .regular : .semibold))
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background {
            if target != nil {
                Color.primary.opacity(0.08)
            }
        }
        .modifier(OptionalTarget(target: target))
    }
}

private struct OptionalTarget: ViewModifier {
    let target: GuideTarget?

    func body(content: Content) -> some View {
        if let target {
            content.guideTarget(target)
        } else {
            content
        }
    }
}

struct GuideLayout {
    let size: CGSize
    let bezel: CGFloat = 6
    let top: CGFloat = 22
    /// The stage fades to clear over its last stretch, so the phone runs on behind the words.
    let fade: CGFloat = 90
    let clusterScale: CGFloat = 0.62

    var phoneWidth: CGFloat {
        min(size.width - 110, 292)
    }

    var phoneHeight: CGFloat {
        phoneWidth * 2.05
    }

    var phoneCenter: CGPoint {
        CGPoint(x: size.width / 2, y: top + phoneHeight / 2)
    }

    var screen: CGRect {
        CGRect(
            x: phoneCenter.x - phoneWidth / 2 + bezel,
            y: top + bezel,
            width: phoneWidth - bezel * 2,
            height: phoneHeight - bezel * 2
        )
    }

    var clearBottom: CGFloat {
        size.height - fade
    }

    /// How far the mock lifts its bottom-anchored parts so they sit above the fade.
    var screenInset: CGFloat {
        max(screen.maxY - clearBottom, 0)
    }

    var plusCenter: CGPoint {
        CGPoint(x: screen.maxX - 30, y: min(screen.maxY, clearBottom) - 26)
    }

    var sunnyTop: CGFloat {
        screen.minY + 104
    }

    var lateTop: CGFloat {
        sunnyTop + (8 + GuideSample.place.height + 10 + GuideSample.clip.height) * clusterScale + 36
    }
}

/// A cluster label on a paper slip, handwritten while the board's Handwriting flag is on, upright when it's off.
struct GuideSlip: View {
    let text: String
    let tilt: Double

    @AppStorage(Mood.handwritingKey) private var handwriting = true

    var body: some View {
        Text(text)
            .font(handwriting ? .custom(Mood.handFontName, size: 18) : .system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.953, green: 0.914, blue: 0.855))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color(red: 0.227, green: 0.196, blue: 0.169), in: .rect(cornerRadius: 3))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            .rotationEffect(.degrees(tilt))
    }
}

/// Night's add buttons at the foot of the board: the camera, and add.
struct GuideBottomBar: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "camera")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .glassEffect(.regular, in: .circle)
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .frame(width: 42, height: 42)
                .glassEffect(.regular, in: .circle)
                .guideTarget(.plus)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// A drawn arrow to the thing to tap, with no words: the step's one line says what's going on.
struct GuideArrow: View {
    let target: CGRect
    let hint: GuideHint
    let bounds: CGSize

    var body: some View {
        let start = CGPoint(
            x: min(max(target.midX + hint.offset.width, 24), bounds.width - 24),
            y: target.midY + hint.offset.height
        )
        let dx = target.midX - start.x
        let dy = target.midY - start.y
        let length = max(hypot(dx, dy), 1)
        let unit = CGPoint(x: dx / length, y: dy / length)
        let reach = min(target.width, target.height) / 2 + 6
        let tip = CGPoint(x: target.midX - unit.x * reach, y: target.midY - unit.y * reach)
        let bend = 0.2 * hypot(tip.x - start.x, tip.y - start.y)
        let control = CGPoint(x: (start.x + tip.x) / 2 - unit.y * bend, y: (start.y + tip.y) / 2 + unit.x * bend)
        let angle = atan2(tip.y - control.y, tip.x - control.x)
        Path { path in
            path.move(to: start)
            path.addQuadCurve(to: tip, control: control)
            path.addLine(to: CGPoint(x: tip.x - 9 * cos(angle - 0.5), y: tip.y - 9 * sin(angle - 0.5)))
            path.move(to: tip)
            path.addLine(to: CGPoint(x: tip.x - 9 * cos(angle + 0.5), y: tip.y - 9 * sin(angle + 0.5)))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        .allowsHitTesting(false)
    }
}
