# Glass

Owner: APPD-12. The glass look's views, a Liquid Glass board that reads and writes the same `Drop` records as the paper look in `ios/Board`. `GlassBoardRoot` is the entry point that `ios/App/RootView.swift` shows when the look is glass.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build. Shared logic (modes, location, notifications, parsing, seed) lives in `ios/Shared`, `ios/Location`, `ios/Notifications` and `ios/Seed`, not here.
