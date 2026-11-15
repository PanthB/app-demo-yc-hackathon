import os
import SwiftUI

enum GuideStep: Int, CaseIterable {
    case welcome, share, add, vibes

    func lead(shared: Bool) -> String {
        switch self {
        case .welcome: "welcome"
        case .share: "share it from any app."
        case .add: "or add one right here."
        case .vibes: shared ? "\(Onboarding.demoBoardName) sorts itself by mood." : "shared boards sort by mood."
        }
    }

    var rest: String {
        switch self {
        case .welcome: "one board for everything you and your friends share."
        case .share: "tap share in spotify, maps or tiktok."
        case .add: "drop in a song, a restaurant or a wikipedia page."
        case .vibes: "drops that feel alike end up side by side."
        }
    }
}

/// The first run: an animated welcome with demo and start fresh, the sign-in sheet for start fresh, and a
/// three-step guide. The background, the top bar, the words and the bottom button stay where they are; only
/// what's in them changes.
struct OnboardingFlow: View {
    let onFinish: (OnboardingResult) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BoardsStore.self) private var boards
    @State private var step: GuideStep = .welcome
    @State private var start: OnboardingResult.Start = .demo
    @State private var askingToSignIn = false
    @State private var welcomeHidden = false
    @State private var name: String?
    @State private var fanned = false
    @State private var titleProgress: Double = 0
    @State private var detailsShown = false
    @State private var finished = false
    @State private var demoBoardId: String?

    private var inGuide: Bool { step != .welcome }

    var body: some View {
        ZStack {
            NightBackdrop(palette: .astral)
            VStack(spacing: 0) {
                topBar
                ZStack {
                    WelcomeFan(fanned: fanned, shown: !inGuide, dimmed: welcomeHidden)
                    if inGuide {
                        GuideStage(step: step, shared: start == .demo || step == .vibes)
                            .transition(.identity)
                    }
                }
                .frame(maxHeight: .infinity)
                words
                dots
                controls
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $askingToSignIn, onDismiss: { if step == .welcome { go(to: .share) } }) {
            SignInSheet(onDone: arrived)
                .presentationDetents([.height(SignInSheet.height)])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.selection, trigger: step)
        .task {
            await enter()
            #if DEBUG
            await autoplay()
            #endif
        }
    }

    // MARK: pieces

    private var topBar: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("back")
            Spacer()
            Button(action: finish) {
                HStack(spacing: 4) {
                    Text("skip")
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                }
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .accessibilityIdentifier("onboardingSkip")
        }
        .padding(.horizontal, 24)
        .frame(height: 44)
        .opacity(inGuide ? 1 : 0)
        .animation(motion(.smooth(duration: 0.3).delay(inGuide ? 0.12 : 0)), value: inGuide)
        .allowsHitTesting(inGuide)
    }

    private var words: some View {
        ZStack(alignment: .topLeading) {
            if inGuide {
                WordsText(lead: step.lead(shared: start == .demo), rest: step.rest, size: 24)
                    .frame(maxWidth: step == .share ? 330 : .infinity, alignment: .leading)
                    .id(step)
                    .transition(.blurReplace)
                    .accessibilityAddTraits(.isHeader)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(GuideStep.welcome.lead(shared: true))
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                        .textRenderer(RiseInText(progress: titleProgress))
                        .accessibilityAddTraits(.isHeader)
                    if detailsShown {
                        WordsText(lead: "", rest: GuideStep.welcome.rest, size: 22)
                    }
                }
                .opacity(welcomeHidden ? 0 : 1)
                .blur(radius: welcomeHidden ? 12 : 0)
                .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: inGuide ? 92 : 150, alignment: .topLeading)
        .padding(.horizontal, 24)
    }

    private var dots: some View {
        GuideDots(current: step.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .opacity(inGuide ? 1 : 0)
            .animation(motion(.smooth(duration: 0.3).delay(inGuide ? 0.55 : 0)), value: inGuide)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button(action: primaryTapped) {
                ZStack {
                    Text(primaryLabel)
                        .id(primaryLabel)
                        .transition(.asymmetric(
                            insertion: AnyTransition(.blurReplace).animation(motion(.smooth(duration: 0.2).delay(0.12))),
                            removal: AnyTransition(.blurReplace).animation(motion(.smooth(duration: 0.12)))
                        ))
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 40)
                .animation(motion(.smooth(duration: 0.3)), value: primaryLabel)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .accessibilityIdentifier(inGuide ? "onboardingNext" : "onboardingDemo")

            if !inGuide {
                Button {
                    choose(.fresh)
                } label: {
                    Text("start fresh")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingFresh")
                .opacity(welcomeHidden ? 0 : 1)
                .blur(radius: welcomeHidden ? 12 : 0)
                .transition(.blurReplace)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .opacity(controlsShown ? 1 : 0)
        .blur(radius: controlsShown || !detailsShown ? 0 : 12)
        .offset(y: detailsShown ? 0 : 24)
        .animation(motion(.smooth(duration: 0.3).delay(controlsShown ? 0.1 : 0)), value: controlsShown)
        .allowsHitTesting(controlsShown)
    }

    private var controlsShown: Bool {
        detailsShown && (inGuide || !welcomeHidden)
    }

    private var primaryLabel: String {
        switch step {
        case .welcome: "demo"
        case .share, .add: "next"
        case .vibes: start == .demo ? "open \(Onboarding.demoBoardName)" : "open my board"
        }
    }

    // MARK: actions

    private func enter() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) {
                fanned = true
                titleProgress = 1
                detailsShown = true
            }
            return
        }
        try? await Task.sleep(for: .milliseconds(200))
        fanned = true
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.linear(duration: 0.9)) { titleProgress = 1 }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(.smooth(duration: 0.6)) { detailsShown = true }
    }

    #if DEBUG
    /// `-OnboardingAutoplay YES` plays the whole flow by itself (demo, or fresh with `-OnboardingAutoplayStart fresh`),
    /// going in as a guest from the sign-in sheet, so a headless Simulator can record it.
    private func autoplay() async {
        guard UserDefaults.standard.bool(forKey: "OnboardingAutoplay") else { return }
        let fresh = UserDefaults.standard.string(forKey: "OnboardingAutoplayStart") == "fresh"
        let beats: [(Double, () -> Void)] = [
            (1.8, { choose(fresh ? .fresh : .demo) }),
            (fresh ? 2.2 : 0, {
                guard askingToSignIn else { return }
                arrived(.guest)
            }),
            (5.0, { go(to: .add) }),
            (3.8, { go(to: .vibes) }),
            (4.6, { finish() }),
        ]
        for (wait, beat) in beats {
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            beat()
        }
    }
    #endif

    private func primaryTapped() {
        switch step {
        case .welcome: choose(.demo)
        case .share: go(to: .add)
        case .add: go(to: .vibes)
        case .vibes: finish()
        }
    }

    /// Demo goes straight into the guide, joining sf crew while the guide plays: a board needs no account.
    /// Start fresh offers the sign-in sheet first, unless someone is already signed in or Apple is switched off.
    private func choose(_ choice: OnboardingResult.Start) {
        start = choice
        Logger.onboarding.info("picked \(choice.rawValue, privacy: .public)")
        if choice == .demo && demoBoardId == nil {
            Task { await joinDemo() }
        }
        if let session = AccountStore.shared.session {
            name = session.firstName
        }
        if choice == .demo || AccountStore.shared.session != nil || !SignInSheet.isAvailable {
            go(to: .share)
            return
        }
        askingToSignIn = true
        withAnimation(motion(.smooth(duration: 0.25))) { welcomeHidden = true }
    }

    /// The sheet's answer. A guest carries on as this phone's person. Demo switches to sf crew. A signed-in person
    /// may have become the person their Apple account already had, so the boards store starts over for them.
    private func arrived(_ outcome: SignInOutcome) {
        askingToSignIn = false
        switch outcome {
        case .guest:
            Logger.onboarding.info("going in as a guest")
        case .demo:
            start = .demo
            Logger.onboarding.info("picked demo from the sign-in sheet")
            if demoBoardId == nil {
                Task { await joinDemo() }
            }
        case .signedIn(let session):
            name = session.firstName
            boards.start()
        }
        go(to: .share)
    }

    private func go(to next: GuideStep) {
        let crossing = step == .welcome || next == .welcome
        withAnimation(motion(crossing ? .smooth(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.86))) {
            step = next
        }
    }

    private func back() {
        guard let previous = GuideStep(rawValue: step.rawValue - 1) else { return }
        if previous == .welcome { welcomeHidden = false }
        go(to: previous)
    }

    /// Makes the chosen board the current one, then hands the result to the shell, which removes the flow with
    /// `.transition(.onboardingExit)` over the board.
    private func finish() {
        guard !finished else { return }
        finished = true
        Onboarding.markDone()
        Logger.onboarding.info("finished onboarding into \(start.rawValue, privacy: .public)")
        switch start {
        case .demo:
            if let demoBoardId {
                boards.show(demoBoardId)
            } else {
                Task { await joinDemo() }
            }
        case .fresh:
            boards.show(BoardKeys.personalBoard)
        }
        onFinish(OnboardingResult(start: start, name: name))
    }

    /// Joining is safe to repeat; the store makes the board current when it lands.
    private func joinDemo() async {
        do {
            let board = try await boards.join(code: Onboarding.demoInviteCode, as: nil)
            demoBoardId = board.boardId
        } catch {
            Logger.onboarding.error("couldn't join the demo board: \(String(describing: error), privacy: .public)")
        }
    }

    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : animation
    }
}

/// How the shell takes the flow away: it lifts a touch, blurs and fades, and the board underneath shows through.
struct OnboardingExit: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 1.04)
            .blur(radius: phase.isIdentity ? 0 : 10)
    }
}

extension Transition where Self == OnboardingExit {
    static var onboardingExit: OnboardingExit { OnboardingExit() }
}

struct GuideDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == current ? 1 : 0.35))
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("step \(max(current, 1)) of 3")
    }
}

#Preview {
    OnboardingFlow { _ in }
        .environment(BoardsStore())
}
