# Revyl

This folder holds the [Revyl](https://revyl.com) project for the native SwiftUI app in `ios/`: the cloud build recipe and the plain-English device tests. The Revyl agent skills are in `.agents/skills/revyl-cli-*`, with links in `.claude/skills/` so Claude Code finds them too.

| Thing | Value |
| --- | --- |
| Revyl org | Panth s workspace |
| Revyl app | `app-demo-yc-hackathon` (iOS), id `75c6da70-69c5-45a4-afc5-2fa1be790927` |
| Revyl project | `8c97d6c0-b9d3-48e2-b81d-42f0868829f3` |
| Build profile | `preview`: a simulator .app built with XcodeGen and xcodebuild |
| Device | Revyl's default, iPhone 17 Pro Max on iOS 27.0 |

## Install and sign in

```bash
curl -fsSL https://revyl.com/install.sh | sh
export PATH="$HOME/.revyl/bin:$PATH"
revyl auth login          # prints a link and a code; approve it in any browser within 10 minutes
revyl auth status
revyl config validate
```

## Build

`config.yaml` has one profile, `preview`, so you can leave out `--profile`. The build runs on Revyl's macOS runners, not on your machine:

1. `brew install xcodegen`, skipped if the runner already has it
2. `cd ios && xcodegen generate`, which turns `ios/project.yml` into `AppDemo.xcodeproj`
3. `xcodebuild -scheme AppDemo -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'`. It has no `CODE_SIGNING_ALLOWED=NO`, because the app and its share extension are ad-hoc signed so the app group entitlement is embedded.
4. Upload `ios/build/Build/Products/Debug-iphonesimulator/AppDemo.app` to the Revyl app

```bash
revyl build --platform ios --json        # copy build_version_id from the output
```

A cold build takes about 9 minutes. With Revyl's compilation cache warm, it takes about 2. If the target, scheme or configuration in `ios/project.yml` changes, update the commands and `output_path` in `config.yaml` to match.

## Tests

Every test is a plain-English YAML file in `tests/`. Revyl's agent reads the screen, so the tests use no selectors.

| Test | Flow | State |
| --- | --- | --- |
| `add-moment-coffee-with-sam` | The hackathon guide's core flow on the starter moments screen: add "Coffee with Sam" and check it's at the top of today's list. It's tagged `moments-skeleton`; delete it when the board replaces that screen. | On Revyl (v2) and passing; see `evidence/` |
| `phase1-1-share-into-board` | Share a link from Safari and a photo from Photos, then see "dropped it, i'll find it a spot." | Draft, local only |
| `phase1-2-drop-lands-on-board` | A shared link shows up on the board right away, then settles into a zone. | Draft, local only |
| `phase1-3-drag-between-zones` | Drag between zones, undo, and check that a manual move survives a relaunch. | Draft, local only |
| `phase1-4-tag-flip` | Tap an object to flip it to its tag (who, what was read, when), then flip it back. | Draft, local only |
| `phase1-5-countdown-notification` | "remind me in 1 hr" shows a countdown, and "remind me in 1 minute" fires a real local notification. | Draft, local only |
| `phase1-6a-wandering-mode` | Moving the simulated location next to a saved place switches to wandering mode, and the mode doesn't change while the context stays the same. | Draft, local only |
| `phase1-6b-planning-mode` | Planning mode at home in the evening. It needs the DEBUG hooks listed under "App hooks the drafts need". | Draft, local only |

The phase 1 drafts pass `revyl test validate`. They aren't pushed to Revyl yet, because their screens don't exist. When a flow lands on main, publish its test and run it against a fresh build:

```bash
revyl test create --from-file .revyl/tests/<name>.yaml --app 75c6da70-69c5-45a4-afc5-2fa1be790927 --no-open
revyl test run <name> --build-id <build_version_id> --no-open --json
revyl test report <name> --json        # steps, reasoning, screenshots and the run video URL
```

After editing a published test, run `revyl test push <name> --force`.

Write tests so they can't pass on data left over from an earlier run. The Convex dev deployment is shared, so a "Coffee with Sam" row from an earlier run stays in the list. The first version of the moments test passed a second time without doing anything, because the agent saw the old row and treated the add step as done. The test now posts a new row by "Revyl" and checks that the top row was posted just now.

## App hooks the drafts need

These changes live in `ios/`, so they go through the Captain to their owners:

- **Share confirmation stays visible.** The share extension should keep "dropped it, i'll find it a spot." on screen for about 2 seconds, or until it's tapped. In the device probe, the sheet was already gone by the time the next step looked at the screen.
- **An on-screen undo control after a manual move.** Test steps can't shake the device, so undo needs something to tap.
- **Notification permission is requested** before the first countdown is scheduled. Remote pushes from `revyl device push` also need it.
- **DEBUG-only clock and home overrides for planning mode:** `BoardDebugNow` (an ISO 8601 time the board treats as now) and `BoardDebugHome` (`"lat,lng"`). On iOS, Revyl passes launch values as `-KEY value` argument pairs, which `UserDefaults.standard` reads without any parsing. Run the test with `revyl test run phase1-6b-planning-mode --launch-arg -BoardDebugNow --launch-arg 2026-11-15T20:30:00-08:00 --launch-arg -BoardDebugHome --launch-arg 37.7793,-122.4193`.
- **The share target is called "Moments".** The tests read it from the `share-target` variable, so change that value if the extension's display name changes.

## What a Revyl device can do

Checked on a live session against the skeleton build (session `290dfc26-f50e-49b5-8417-00b324e6aa35`):

- **Share sheet: works.** `revyl device navigate <url>` opened the link in Safari. One plain-English step then tapped Share and picked Moments from the share sheet, and the app's inbox showed the link waiting. No share command is needed.
- **Location: works.** `revyl device set-location --lat 37.7614 --lon -122.4241` put the blue dot at Guerrero and 18th in Maps. In test YAML, use a `manual` step with `step_type: set_location` and value `"lat,lng"`, or pass `revyl test run --location lat,lng`. There's no route playback, so a walk is a series of set_location steps.
- **Photos: the library has 6 built-in sample photos**, so share-from-Photos tests can use those. `revyl device download-file` failed on a Wikimedia image URL, so it's still unknown whether a downloaded image lands in Photos.
- **Remote push: not working yet.** `revyl device push --bundle-id com.panthb.appdemo` returned "simctl push failed". The skeleton never asks for notification permission, which is the likely cause. Try again once the app requests it.
- **Local notifications:** not checked, because nothing in the app schedules one yet. `phase1-5` covers this.
- **Video:** every test run and device session report includes a video (`video_url` in `revyl test report --json` or `revyl device report --json`), plus step screenshots, device logs and network traffic.

## Drive a device by hand

```bash
revyl device start --platform ios --build-version-id <build_version_id> --open=false --json   # viewer_url shows the live device
revyl device navigate --session-id "$SID" --url https://example.com
revyl device instruction --session-id "$SID" "Tap Share and pick Moments."
revyl device set-location --session-id "$SID" --lat 37.7614 --lon -122.4241
revyl device screenshot --session-id "$SID" --out after.png
revyl device validation --session-id "$SID" "The home screen shows today's moments." --json
revyl device stop --session-id "$SID"     # stop as soon as you're done; phones bill by the minute
```

## Manual steps for Panth

These need a person signed in to the dashboards:

1. **Connect Revyl to Capy:** in Capy, create a key under Settings → API. In Revyl, open Integrations → Capy → Connect Capy, paste the key, and pick the `app-demo-yc-hackathon` project.
2. **Install the Revyl GitHub App** on `panthb/app-demo-yc-hackathon` (`revyl github connect` prints the link). Until then, `revyl config validate` passes its local check but reports that it can't reach the repository. Installing it also lets Revyl post device verdicts on pull requests.
