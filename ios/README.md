# iOS app

Native Swift and SwiftUI app (iOS 26+) with a share extension, a SwiftData board store in an app group, and the Convex backend through [ConvexMobile](https://github.com/convex/convex-swift). The Xcode project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). Only the spec is committed, never `AppDemo.xcodeproj`.

## Targets

| Target | Bundle id | Compiles |
| - | - | - |
| `AppDemo` (app, scheme `AppDemo`) | `com.panthb.appdemo` | `App`, `Shared`, `Board`, `Glass`, `Location`, `Notifications`, `Seed`, `Ingest`, `Sync`, plus `Assets` as resources, plus ConvexMobile 0.8.2 |
| `ShareExtension` (share extension, embedded in the app) | `com.panthb.appdemo.share` | `ShareExtension`, `Shared` |
| `AppDemoTests` (unit tests, hosted in the app) | `com.panthb.appdemo.tests` | `Tests` |

Sources are included by folder, so adding or removing a Swift file needs no change to `project.yml`. Markdown files are excluded from every target. Rerun `xcodegen generate` after pulling.

## Folders and owners

| Folder | Owner | What lives there |
| - | - | - |
| `project.yml`, `Config/` | APPD-3 | The spec, xcconfig, Info.plists and entitlements |
| `App/` | APPD-3 | App entry point, `RootView` (the view switch, the board clock, the drop actions and the DEBUG links), the one `convex` client and the bundled hand font (`Fonts/Caveat.ttf`, OFL) |
| `Shared/` | APPD-3 | The seam between the board, glass and ingest: the `Drop` model, the shared vocabulary, the app group, the inbox format, the time-word parser, and the logic every view uses (sections, drop actions, zone clock, tags, media) |
| `Board/` | APPD-3 | The board view (the corkboard), and nothing else |
| `Glass/` | APPD-12 | The cards and list views and the item parts (pill, avatar, card, row, detail) |
| `Location/`, `Notifications/`, `Seed/` | APPD-3 | Location and modes, countdown notifications, and DEBUG seed data, shared by every view |
| `ShareExtension/`, `Ingest/`, `Sync/` | share and ingest thread (PAN-5) | The share extension, inbox processing and Convex sync |
| `Assets/` | APPD-8 owns `Kit.xcassets` | Asset catalogs, bundled as resources by folder |
| `Tests/` | whoever owns the code under test | XCTest files |

## Configuration

`Config/AppDemo.xcconfig` is the one place for deployment values, and both targets use it:

- `CONVEX_URL` is the Convex deployment, surfaced to Swift through the `CONVEX_URL` Info.plist key. Write it as `https:/$()/<name>.convex.cloud`, because `//` starts a comment in xcconfig files.
- `APP_GROUP_ID` (`group.com.panthb.appdemo`) feeds both entitlements files and the `APP_GROUP_ID` Info.plist key that `Shared/AppGroup.swift` reads.

Simulator builds are ad-hoc signed ("Sign to Run Locally", identity `-`, no team), so the app group entitlement is embedded without a certificate. Device builds sign automatically with the Skan Beauty team (`JD9H683DWQ`); build them with `-allowProvisioningUpdates` the first time so Xcode makes the team profiles.

## Views

The app shows the same `Drop` records four ways. Night (`ios/Night`, APPD-20) is the flagship and the default for new installs: a dark-only view that RootView shows full screen with its own header and views menu, and none of the shell. The views menu leads to the other three: list, cards and board (the corkboard in `ios/Board`, or `ios/Clusters` when the board is arranged by mood).

`App/BoardShell.swift` hosts the other three in one NavigationStack for the current board from `BoardsStore`. The inline title is the board menu (switch boards, invite friends to a shared board with its link and code, start a shared board, join with a code). The arrange menu picks "by when" or "by mood" per board (personal boards start by when, shared boards by mood) and, in the board view, turns the handwriting and the lines between related drops on or off (lines start off). Shared boards add the everyone and mine control under the title and the members' avatars, which open the invite sheet. The lightbulb, "suggestions", opens APPD-12's `SuggestionsFeed` for the board in a sheet. The bottom glass bar switches views and holds `AddMenu`. A tapped drop opens `DropDetailView` with the zoom transition, using the one namespace every view gets. When a friend's drop arrives on the current board, a glass toast at the top says who added what ("maya added a song.") for 2 seconds.

`App/SettingsSheet.swift` is what night's "settings" button opens (`SettingsButton`): the theme, night or scrapbook (the board view), the scrapbook's handwriting and lines switches, and the two suggestion switches the suggestions feed also shows, sent through `people:setPrefs`.

On first launch `RootView` lays APPD-17's `OnboardingFlow` over the shell and removes it with `.onboardingExit`. Both paths end in night: demo on sf crew, and start fresh on the person's own board.

The stored view lives in `UserDefaults` key `viewMode`. The launch argument `-view list`, `-view cards`, `-view board` or `-view night` sets it once at launch, so the bar still switches views in a test run. Cloud phones can't pass launch arguments, so the app also handles the `appdemo` URL scheme: open `appdemo://view/list`, `appdemo://view/cards`, `appdemo://view/board` or `appdemo://view/night` (with `tools.capy.phone` `action: "open_url"`) to store the setting and switch right away.

### DEBUG switches

DEBUG builds read these from `UserDefaults.standard`, so a launch argument like `-BoardDebugSeed YES` sets them:

| key | value | effect |
| - | - | - |
| `BoardDebugSeed` | `YES` | replaces the boards with the two sample boards on launch and opens "my board"; sync stays offline, and onboarding is skipped unless `OnboardingReset` is also `YES` |
| `BoardDebugNow` | ISO 8601, like `2026-11-21T18:30:00-08:00` | the board clock's time, so time-based placement can be tested at any hour |
| `BoardDebugAnchor` | `bottom` | opens the board scrolled to the bottom, so a headless Simulator can screenshot the vibes and done rows |
| `Handwriting` | `NO` | sets the corkboard's headers and notes in the rounded system font instead of Caveat (also in the arrange menu as "handwriting") |
| `BoardLines` | `YES` | draws the strings between related drops on the board, which are off by default (also in the arrange menu as "lines") |

The links `appdemo://seed` (replace the board with the sample board) and `appdemo://clear` (empty it) do the same from a cloud phone. In a seeded session, `appdemo://arrive` drops a song from maya onto the current board, to show the arrival toast. The seed is two boards: panth's personal "my board" (`seed-panth-board`), the time-based set, and the shared "sf crew" (`sf-crew`), 15 places, clips and songs in three mood clusters with their vibes, labels and neighbors. Seeding makes this device panth (`seed-panth`, with `seed-panth-board` as its personal board), so "mine" shows panth's drops. Both match the backend's seed drop for drop, with the same client ids; the list is in `handoffs/APPD-3/seed.md` in the Captain's drive. The title menu lists both seeded boards even while sync is offline. Seed data and its images (`Seed/SeedImages.xcassets`) are DEBUG only.

## Shared model

- `Drop` (SwiftData) holds identity, raw input, what was read, what it became and what the person did, using the zone, type, objectKind, emphasis and status names from the phase 1 plan. The shared-board fields follow the Convex contract: `authorId` (who saved it, renamed from `dropperId` with the old store column kept), `authorName`, `authorColor` (a SwiftUI color name), `boardId`, `pinnedAt` (`isPinned` when it's set) and `suggestion`. Enum fields are stored as raw strings (`zoneRaw` and friends) so predicates work, with typed accessors on top.
- `Drop.applyDecidedZone(_:unsure:)` is how the pipeline places a drop. It does nothing once the person moved the drop. Pinning doesn't hold a zone: `setPinned(_:)` only sets or clears `pinnedAt`, so an unpinned drop goes back to its section. `moveByUser(to:x:y:)` and `undoMove()` are the person's side.
- `BoardStore.makeContainer()` opens `Board.store` in the app group container.
- `DeviceIdentity.personId` and `.boardId` are created on first use and kept in the app group's defaults, so the extension sees the same ids.
- `Inbox` is a folder per drop at `<app group>/inbox/<uuid>/` holding `drop.json` and the payload files. Writes go to `inbox/.staging/<uuid>/` first and move into place in one step, so a reader never sees half a drop. `Inbox.shared` is the app group inbox.
- `TimeWords.parse(_:now:calendar:)` turns time words into a `dueAt` (reminders and "in 1 hr" countdowns) or a `startsAt`, a zone hint and a lowercase `whenLabel`.
- `Drop.artist` is the artist of a song link (APPD-11 fills it from link previews and `enrichment.author`). `Drop.mediaDuration` is a voice note's length in seconds.
- `ZoneClock` works the zone out again from `startsAt` and `dueAt` with no model call (U6): within 90 minutes or later today before 5pm is now, this evening and the small hours are tonight, Friday 5pm to Sunday night is this weekend. Time only moves a drop toward now, and a drop the person moved, vibes and done never move. `Drop.boardZone(now:)` is the zone to draw. `BoardContents(drops, now:)` groups drops by it.
- `DropSection.build(_:grouping:filter:me:now:)` is what every view lays out, with empty sections left out. Pinned comes first (newest pin first), and a pinned drop sits only there until it's done. Grouped `.when`, the rest follows as now, tonight, this weekend, someday and vibes, with an arriving drop leading now. Grouped `.vibe`, it's one section per `clusterId` titled with its `clusterLabel` (biggest first, then the one with the newest drop), then "everything else" for drops with no cluster. Done is always last. `DropFilter` is everyone or mine (`authorId == me`).
- The mood fields follow the Convex contract: `vibes`, `clusterId`, `clusterLabel`, `neighbors` (`DropNeighbor`, a client id and a reason) and `genre`.
- `DropActions` (`@Environment(\.dropActions)`) is how any view pins, moves, marks done, undoes and opens a drop. The defaults change SwiftData only. `RootView` installs `open`, and the shell swaps in the sync versions, so views never call ios/Sync directly.
- `BoardClock` (in the environment from `RootView`) is the `now` every view lays out with. It ticks when the app comes to the foreground and at the time-of-day boundaries (midnight, 5am, noon, 5pm, 10pm), never on a running timer.
- `DropFace` formats what an object's front says: the short title (three words at most), the when tag (`7:30pm`, `sat 8pm`, `sometime in march`, or `sometime` when a drop has no time) and the countdown. `MediaStore` saves and caches images under `media/` in the app group. `StableRandom` seeds tilt and placement from a drop's id, so they never change between launches.

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

`TimeWordsTests`, `InboxTests`, `ViewModeTests` and `ZoneClockTests` cover pure Foundation code, so they also run on Linux with the `swift:6.1` Docker image. Put `Shared/Vocabulary.swift`, `Shared/TimeWords.swift`, `Shared/Inbox.swift`, `Shared/ViewMode.swift`, `Shared/ZoneClock.swift` and `Shared/DropFace.swift` in a SwiftPM target named `AppDemo`, put `Tests/*.swift` in a test target, and run `swift test`.

## Backend contract

The deployment is `https://adorable-coyote-696.convex.cloud`. The drop contract lives at `handoffs/APPD-1/convex-contract.md` in the Captain's drive.

## Logs

Cloud iPhones only capture `os_log` and `NSLog`. Use the loggers in `Shared/Log.swift` (subsystem `com.panthb.appdemo`, categories `app`, `store`, `inbox` and `share`) with `privacy: .public` on anything worth reading, and read them with `tools.capy.phone` `action: "logs"`.
