# iOS app

Native Swift and SwiftUI app (iOS 17+) that talks to the Convex backend through [ConvexMobile](https://github.com/convex/convex-swift). The Xcode project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). Only the spec is committed, never `AppDemo.xcodeproj`.

## Layout

| Path | What it is |
| - | - |
| `project.yml` | XcodeGen spec: the `AppDemo` target and scheme, iOS 17.0, and the ConvexMobile package pinned to 0.8.2 |
| `Config/AppDemo.xcconfig` | The one place the Convex deployment URL lives (`CONVEX_URL`) |
| `Config/Info.plist` | Surfaces `CONVEX_URL` as an Info.plist key. Xcode generates every other key at build time (`GENERATE_INFOPLIST_FILE`) |
| `AppDemo/Convex.swift` | The shared `ConvexClient`, read from Info.plist, and the `os` logger |
| `AppDemo/MomentsView.swift` | Home screen: live `moments:list` subscription, newest first |
| `AppDemo/ComposerView.swift` | Composer sheet that calls `moments:add` |
| `.capyignore` | Keeps `build/`, `DerivedData/` and generated projects out of Revyl uploads |

Bundle id is `com.panthb.appdemo`, and the home-screen name is "Moments". Both are placeholders until the product idea lands.

## Build on Revyl through Capy

Cloud machines have no Xcode, so Capy builds on Revyl's macOS runners with `tools.mobile.build`. The source path is relative to the workspace root, and these are the exact commands:

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
      "xcodebuild -project AppDemo.xcodeproj -scheme AppDemo -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build",
    ],
    output_path: "build/Build/Products/Debug-iphonesimulator/AppDemo.app",
  },
});
```

Then install the succeeded build on a cloud iPhone with `tools.capy.phone` (`action: "install"`, the phone's `machine`, and the `build_id`). The Revyl app name is `app-demo`, so every thread's builds version together.

## Build on a Mac

```sh
cd ios
brew install xcodegen
xcodegen generate
open AppDemo.xcodeproj
```

Or build from the command line with the same `xcodebuild` line as above. ConvexMobile's Rust core ships only arm64 simulator slices, so `project.yml` excludes x86_64 for the simulator SDK and the app runs only on Apple silicon simulators. Rerun `xcodegen generate` whenever you add, move or delete files, or change `project.yml`.

## Backend contract

The app uses two Convex functions on `https://adorable-coyote-696.convex.cloud`:

- query `moments:list` with no args returns `[{ _id, _creationTime, text, author, createdAt }]`, newest first.
- mutation `moments:add` takes `{ text, author }` and returns the new id.

To point the app at another deployment, change `CONVEX_URL` in `Config/AppDemo.xcconfig`. Write it as `https:/$()/<name>.convex.cloud`, because `//` starts a comment in xcconfig files.

## Logs

Cloud iPhones only capture `os_log` and `NSLog`, so the app logs through `Logger` (subsystem `com.panthb.appdemo`, category `app`) with `privacy: .public` on anything worth reading. Read them with `tools.capy.phone` `action: "logs"`. Failed subscriptions and mutations log at error level, and a missing `CONVEX_URL` logs a fault before the app stops.
