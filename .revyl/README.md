# Revyl

This folder holds the [Revyl](https://revyl.com) project for the native SwiftUI app in `ios/`: the cloud build recipe and the plain-English device tests. The Revyl agent skills live in `.agents/skills/revyl-cli-*` (linked into `.claude/skills/` for Claude Code).

| Thing | Value |
| --- | --- |
| Revyl org | Panth s workspace |
| Revyl app | `app-demo-yc-hackathon` (iOS), id `75c6da70-69c5-45a4-afc5-2fa1be790927` |
| Revyl project | `8c97d6c0-b9d3-48e2-b81d-42f0868829f3` |
| Build profile | `preview` (iOS simulator .app, XcodeGen + xcodebuild) |
| Test | `add-moment-coffee-with-sam` (remote id `e8e396a3-dfc3-44bd-abda-f32321d1afd9`) |

## Install and sign in

```bash
curl -fsSL https://revyl.com/install.sh | sh
export PATH="$HOME/.revyl/bin:$PATH"
revyl auth login          # prints a link and a code; approve it in any browser within 10 minutes
revyl auth status
revyl config validate
```

## Build

`config.yaml` has one profile, `preview`, so `--profile` is optional. It runs on Revyl's macOS runners, never locally:

1. `brew install xcodegen` (skipped when it's already on the runner)
2. `cd ios && xcodegen generate` turns `ios/project.yml` into `AppDemo.xcodeproj`
3. `xcodebuild -scheme AppDemo -configuration Debug -sdk iphonesimulator` with `CODE_SIGNING_ALLOWED=NO`
4. Uploads `ios/build/Build/Products/Debug-iphonesimulator/AppDemo.app` to the Revyl app

```bash
revyl build --platform ios --json        # copy build_version_id from the output
```

If the iOS target, scheme or configuration in `ios/project.yml` changes, update the commands and `output_path` in `config.yaml` to match.

## Run the test

`tests/add-moment-coffee-with-sam.yaml` is the core flow from the hackathon guide: add a moment called "Coffee with Sam" and check it lands at the top of today's list.

```bash
revyl test run add-moment-coffee-with-sam --build-id <build_version_id> --no-open --json
revyl test report add-moment-coffee-with-sam --json
```

After editing the YAML, push it with `revyl test push add-moment-coffee-with-sam --force`.

## Drive a device by hand

```bash
revyl device start --platform ios --build-version-id <build_version_id> --json   # open viewer_url to watch
revyl device screenshot --session-id "$SESSION_ID" --out after.png
revyl device validation --session-id "$SESSION_ID" "The home screen shows today's moments." --json
revyl device stop --session-id "$SESSION_ID"
```

## Manual steps for Panth

These need a person signed in to the dashboards, so no agent does them:

1. **Connect Revyl to Capy.** In Capy, Settings → API, create a key. In Revyl, Integrations → Capy → Connect Capy, paste it and pick the `app-demo-yc-hackathon` project.
2. **Install the Revyl GitHub App** on `panthb/app-demo-yc-hackathon` (run `revyl github connect` for the link). Until then `revyl config validate` passes locally but reports that connected validation can't reach the repository, and Revyl can't post proof-of-changes verdicts on pull requests.
