# Onboarding

Owner: APPD-17. The first-launch flow, entered through `OnboardingFlow(onFinish:)`.

## For the shell (ios/App)

```swift
@State private var onboarding = Onboarding.isNeeded

ZStack {
    board
    if onboarding {
        OnboardingFlow { result in
            // pick the view underneath first: sf crew by mood for .demo, the person's own board for .fresh
            withAnimation(.smooth(duration: 0.45)) { onboarding = false }
        }
        .transition(.onboardingExit)
        .zIndex(1)
    }
}
```

- `Onboarding.isNeeded` is true until the flow finishes once, and on every DEBUG launch with `-OnboardingReset YES`.
- The flow picks the board itself through `BoardsStore` (from `.dropPipeline()`): **demo** joins sf crew with `boards.join(code: Onboarding.demoInviteCode, as: nil)` while the guide plays, and **fresh** shows `BoardKeys.personalBoard`. So the shell only picks the view: sf crew by mood for demo, the person's own board for fresh. `result.name` is the signed-in first name, or nil.
- The flow marks itself done before it calls `onFinish` and keeps everything on screen. `.onboardingExit` lifts, blurs and fades the whole flow, backdrop included, so the board underneath shows through without a flash.

## What's in it

- `OnboardingFlow`: one screen on `NightBackdrop(palette: .astral)` from ios/Night. The top bar (back, skip), the words, the dots and the bottom button stay put; steps change only what's in them.
- Demo goes straight into the guide. Start fresh offers `SignInSheet` first, at a fixed height, with the welcome faded out behind it. It has the three ways in: continue with apple (linked to this phone's person through `PeopleLink`), continue as a guest, and the sf crew demo.
- `WelcomePile`: five example drops (a song, a link, a place, a photo and a clip, each with a small solid kind pill) that land one by one on a loose pile, with a small "dropped it in sf crew." note under its corner.
- `RiseInText` draws "welcome" glyph by glyph; `WordsText` fades each step's words in.
- `GuideStage` and `GuideScreen`: the guide's phone, taller than the stage and fading out behind the words, and the drops that pile up beside it, deal onto its board and settle into two mood clusters, grouped by space alone. Each step has one plain line, and wordless arrows point at what to tap. The phone's board is night, with night's camera and add buttons. The lines between drops show only with `@AppStorage("BoardLines")` on (default off). Step 3 shows sf crew on both paths, as the example of a shared board.
- `Onboarding.xcassets`: the guide's example photos and artwork, generated for this guide, so they ship in every build.

Reduce Motion turns every move into a 0.25 s cross-fade. With `AppleSignIn.isEnabled` off, start fresh skips the sheet and goes in as a guest.

In DEBUG, `-OnboardingAutoplay YES` plays the flow by itself for recordings, and `-OnboardingAutoplayStart fresh` takes the start-fresh path.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
