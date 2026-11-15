# iOS app

Native Swift and SwiftUI app (iOS 17+) with a share extension, a SwiftData board store in an app group, and the Convex backend through [ConvexMobile](https://github.com/convex/convex-swift). The Xcode project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). Only the spec is committed, never `AppDemo.xcodeproj`.

## Targets

| Target | Bundle id | Compiles |
| - | - | - |
| `AppDemo` (app, scheme `AppDemo`) | `com.panthb.appdemo` | `App`, `Shared`, `Board`, `Location`, `Notifications`, `Seed`, `Ingest`, `Sync`, plus `Assets` as resources, plus ConvexMobile 0.8.2 |
| `ShareExtension` (share extension, embedded in the app) | `com.panthb.appdemo.share` | `ShareExtension`, `Shared` |
| `AppDemoTests` (unit tests, hosted in the app) | `com.panthb.appdemo.tests` | `Tests` |

Sources are included by folder, so adding or removing a Swift file needs no change to `project.yml`. Markdown files are excluded from every target. Rerun `xcodegen generate` after pulling.

## Folders and owners

| Folder | Owner | What lives there |
| - | - | - |
| `project.yml`, `Config/` | APPD-3 | The spec, xcconfig, Info.plists and entitlements |
| `App/` | APPD-3 | App entry point and the one `convex` client. `App/Starter/` is the throwaway moments screen and a DEBUG skeleton check, and the board replaces it |
| `Shared/` | APPD-3 | The seam between the board and ingest: the `Drop` model, the shared vocabulary, the app group, the inbox format and the time-word parser |
| `Board/`, `Location/`, `Notifications/`, `Seed/` | APPD-3 | The board, its location modes, countdown notifications, and DEBUG seed data |
| `ShareExtension/`, `Ingest/`, `Sync/` | share and ingest thread (PAN-5) | The share extension, inbox processing and Convex sync |
| `Assets/` | APPD-8 owns `Kit.xcassets` | Asset catalogs, bundled as resources by folder |
| `Tests/` | whoever owns the code under test | XCTest files |

## Configuration

`Config/AppDemo.xcconfig` is the one place for deployment values, and both targets use it:

- `CONVEX_URL` is the Convex deployment, surfaced to Swift through the `CONVEX_URL` Info.plist key. Write it as `https:/$()/<name>.convex.cloud`, because `//` starts a comment in xcconfig files.
- `APP_GROUP_ID` (`group.com.panthb.appdemo`) feeds both entitlements files and the `APP_GROUP_ID` Info.plist key that `Shared/AppGroup.swift` reads.

Simulator builds are ad-hoc signed ("Sign to Run Locally", identity `-`, no team), so the app group entitlement is embedded without a certificate. Device builds on a Mac need `CODE_SIGN_STYLE: Automatic` and a `DEVELOPMENT_TEAM`.

## Shared model

- `Drop` (SwiftData) holds identity, raw input, what was read, what it became and what the person did, using the zone, type, objectKind, emphasis and status names from the phase 1 plan. Enum fields are stored as raw strings (`zoneRaw` and friends) so predicates work, with typed accessors on top.
- `Drop.applyDecidedZone(_:unsure:)` is how the pipeline places a drop. It does nothing once the person moved or pinned the drop. `moveByUser(to:x:y:)` and `undoMove()` are the board's side.
- `BoardStore.makeContainer()` opens `Board.store` in the app group container.
- `DeviceIdentity.personId` and `.boardId` are created on first use and kept in the app group's defaults, so the extension sees the same ids.
- `Inbox` is a folder per drop at `<app group>/inbox/<uuid>/` holding `drop.json` and the payload files. Writes go to `inbox/.staging/<uuid>/` first and move into place in one step, so a reader never sees half a drop. `Inbox.shared` is the app group inbox.
- `TimeWords.parse(_:now:calendar:)` turns time words into a `dueAt` (reminders and "in 1 hr" countdowns) or a `startsAt`, a zone hint and a lowercase `whenLabel`.

## Build on Revyl through Capy

Cloud machines have no Xcode, so Capy builds on Revyl's macOS runners with `tools.mobile.build`. The source path is relative to the workspace root:

```js
await tools.mobile.build({
  action: "start",
  platform: "ios",
  app: "app-demo",
  source: {
    type: "workspace",
    path: "app-demo-yc-hackathon/ios",
    commands: [
      "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install xcodegen",
      "xcodegen generate",
      "xcodebuild -project AppDemo.xcodeproj -scheme AppDemo -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build build",
    ],
    output_path: "build/Build/Products/Debug-iphonesimulator/AppDemo.app",
  },
});
```

Then install the succeeded build on a cloud iPhone with `tools.capy.phone` (`action: "install"`, the phone's `machine`, and the `build_id`). ConvexMobile's Rust core ships only an arm64 simulator slice, so `project.yml` excludes x86_64 for the simulator SDK and the app runs only on arm64 simulators.

## Build and test on a Mac

```sh
cd ios
brew install xcodegen
xcodegen generate
open AppDemo.xcodeproj
xcodebuild test -project AppDemo.xcodeproj -scheme AppDemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`TimeWordsTests` and `InboxTests` cover pure Foundation code, so they also run on Linux with the `swift:6.1` Docker image. Put `Shared/Vocabulary.swift`, `Shared/TimeWords.swift` and `Shared/Inbox.swift` in a SwiftPM target named `AppDemo`, put `Tests/*.swift` in a test target, and run `swift test`.

## Backend contract

The starter screen uses `moments:list` (query, no args, newest first) and `moments:add` (mutation, `{ text, author }`) on `https://adorable-coyote-696.convex.cloud`. The drop contract lives at `handoffs/APPD-1/convex-contract.md` in the Captain's drive.

## Logs

Cloud iPhones only capture `os_log` and `NSLog`. Use the loggers in `Shared/Log.swift` (subsystem `com.panthb.appdemo`, categories `app`, `store`, `inbox` and `share`) with `privacy: .public` on anything worth reading, and read them with `tools.capy.phone` `action: "logs"`.
