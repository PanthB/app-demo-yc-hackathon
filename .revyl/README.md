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

Every test is a plain-English YAML file in `tests/`. Revyl's agent reads the screen, so the tests use no selectors. None of them is published to Revyl yet. Each one is published and run once the Captain says its flow is on main.

| Test | Flow | State |
| --- | --- | --- |
| `views-1-switch` | Switch from cards to list to board and back. Each view shows the same sections, and a pinned drop stays at the top. | Draft, waits on the views shell |
| `views-2-pin` | Pin a drop from its context menu, see it at the top in cards and list, then unpin it. | Draft, waits on pins |
| `views-3-filter-mine` | Switch the everyone/mine control and check that only the current person's drops remain. | Draft, waits on the filter |
| `views-4-join-by-code` | Join "sf crew" from the title menu with an invite code, and see both boards in the menu. Set `invite-code` once the backend seed has one. | Draft, waits on boards and the seed code |
| `phase1-1-share-into-board` | Share a link from Safari and a photo from Photos, and see the "dropped it" confirmation. | Draft |
| `phase1-2-drop-lands-on-board` | A shared link shows up as an item right away, then settles under a section. | Draft |
| `phase1-5-countdown-notification` | "remind me in 1 hr" shows a live countdown, and "remind me in 1 minute" fires a real local notification. | Draft |
| `phase1-6a-nearby-suggestion` | Moving the simulated location next to a saved place adds a "few min from you" suggestion, and nothing moves while the context stays the same. | Draft |
| `phase1-6b-time-sections` | With the board clock set to Friday 6:30pm, a Saturday note sits under this weekend and a 10pm note under tonight. | Draft |
| `phase1-3-drag-between-zones`, `phase1-4-tag-flip` | Dragging between zones and the tag flip. | Deferred by the views plan, tagged `deferred` |

The views tests start with `appdemo://seed`, the DEBUG link that loads the sample board, so they don't depend on what's already on the device. The first test, `add-moment-coffee-with-sam`, was retired when the board replaced the moments screen. Its runs are still in the Revyl dashboard, and `evidence/` keeps the record.

Publish a test and run it against a fresh build:

```bash
revyl build --platform ios --json        # copy build_version_id
revyl test create --from-file .revyl/tests/<name>.yaml --app 75c6da70-69c5-45a4-afc5-2fa1be790927 --no-open
revyl test run <name> --build-id <build_version_id> --no-open --json
revyl test report <name> --json        # steps, reasoning, screenshots and the run video URL
```

After editing a published test, run `revyl test push <name> --force`. `phase1-6b-time-sections` needs the board clock pinned, so run it with `--launch-arg -BoardDebugNow --launch-arg 2026-11-20T18:30:00-08:00`.

Write tests so they can't pass on data left over from an earlier run. The Convex dev deployment is shared. The first moments test passed a second time without doing anything, because the agent saw a "Coffee with Sam" row from an earlier run and treated the add step as done. Seed the board first, or check for something only this run could have made. A step with zero actions in `revyl test report --json` is a red flag.

## App hooks the tests need

These changes live in `ios/`, so they go through the Captain to their owners:

- **Share confirmation stays visible.** The share extension should keep its "dropped it" line on screen for about 2 seconds, or until it's tapped. In the device probe, the sheet was already gone by the time the next step looked at the screen.
- **Notification permission is requested** before the first countdown is scheduled. Remote pushes from `revyl device push` also need it.
- **The board clock override exists:** `BoardDebugNow` (ISO 8601) is read from `UserDefaults`. On iOS, Revyl passes launch values as `-KEY value` argument pairs, which land there without any parsing.
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
revyl device validation --session-id "$SID" "The cards view shows drops under section headers." --json
revyl device stop --session-id "$SID"     # stop as soon as you're done; phones bill by the minute
```

## Manual steps for Panth

These need a person signed in to the dashboards:

1. **Connect Revyl to Capy:** in Capy, create a key under Settings → API. In Revyl, open Integrations → Capy → Connect Capy, paste the key, and pick the `app-demo-yc-hackathon` project.
2. **Install the Revyl GitHub App** on `panthb/app-demo-yc-hackathon` (`revyl github connect` prints the link). Until then, `revyl config validate` passes its local check but reports that it can't reach the repository. Installing it also lets Revyl post device verdicts on pull requests.
