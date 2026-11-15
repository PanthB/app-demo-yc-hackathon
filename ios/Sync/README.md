# Sync

Owner: the share and ingest thread (PAN-5). Identity, boards, and the two-way sync between SwiftData and Convex. It uses the one `convex` client from `ios/App/Convex.swift` and follows `handoffs/APPD-1/convex-contract.md`. Sign-in isn't here: APPD-17 owns it end to end in `ios/Auth`, including the client in `ios/App/Convex.swift` and `people:link` after sign-in.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## What the shell uses

`.dropPipeline()` on the root view puts two objects in the environment for everything under it.

- **`BoardsStore`** (`@Environment(BoardsStore.self)`), observable:
  - `boards`: every board the person is in, "my board" first. Each `RemoteBoard` has `name`, `shared`, `inviteCode`, `inviteLink` (`appdemo://join/<code>`) and `members` with `name` and `color`.
  - `currentBoardId`, `currentBoard` and `currentBoardName`. Show the drops whose `boardId == currentBoardId`.
  - `show(boardId)` switches boards.
  - `entry = .create` or `entry = .join(code: nil)` opens the sheet that makes or joins a shared board. The sheet asks for the person's name the first time and switches to the new board.
  - `personId` is "me" for the everyone and mine filter.
  - `try await boards.join(code: "SFCREW", as: nil)` joins a board in one call and switches to it. Joining a board the person is already in just opens it, so the first-run "demo" button can call it every time. `create(named:as:)` is the same for a new board. Both throw a `BoardProblem` whose message can be shown as it is.
- **`BoardSync`** (`@Environment(BoardSync.self)`): `setPinned(_:_:)`, `move(_:to:)`, `markDone(_:)` and `undoMove(_:)`. Each changes SwiftData at once and sends the mutation. The shell builds `DropActions` from them.
- **`AddMenu()`** is the add slot's control: a native menu with photo (PhotosPicker), paste link and note. It has no button style of its own, so the shell styles it. What it adds goes through the same inbox as a share.

An `appdemo://join/<code>` link opens the join sheet with the code filled in.

## How the sync works

- **On every wake** (launch and each return to the foreground): ingest the inbox, write the deployment URL to the app group as `convexURL` for the share extension (cleared when the app runs offline), register the person with `people:upsert`, subscribe to `boards:mine`, subscribe to `drops:list` for every board the person is in, and send drops that are still waiting.
- **Sending a drop.** A drop with no `remoteId` and status `pending` is read on the phone first (see `ios/Ingest`), its pictures are uploaded through `files:generateUploadUrl` (at most 4), and then `drops:submit` is called with the drop's id as `clientId`. Submit is idempotent, so a drop that didn't get through is sent again 8 seconds later and on the next wake. A drop whose id the sample board made (`DropKey.isSample`) is never sent, so the sample's "reading this one now" drop can't reach the backend from a phone that later goes online.
- **Reading a board.** Each `drops:list` push is matched to local drops by `clientId`. New ones are inserted, so a friend's drop appears live. Fields the backend read are filled in, the author's name and color and the suggestion are copied as they are, and a preview picture is downloaded to `media/<drop id>/remote.jpg` when the phone has none.
- **Mood.** `vibes`, `clusterId`, `clusterLabel` and `neighbors` are copied from every push as they are, so a drop that the backend moves to another cluster, or takes out of the clusters, moves on the phone too. A neighbor's `clientId` is the other drop's `id.uuidString`. `genre` comes from `enrichment.genre`, and `mediaDuration` from `enrichment.durationSec` (a song's or a clip's length in seconds).
- **Zones.** A pipeline zone goes through `applyDecidedZone`, so it never moves a drop a person placed. A zone a person set (`zoneSetByUser`) goes through `moveByUser`, whoever in the board set it.
- **Pins and moves.** While a pin or move is on its way out, older lists don't undo it.
- **A row the app can't read** is skipped and logged, and the rest of the board still arrives.
- **Numbers** are always sent as `Double`, and times as milliseconds.

## Identity

`DeviceIdentity.personId` is the person. The personal board id the backend returns is kept in the app group, with the person's name and the current board, so the share extension can name the board. In DEBUG, `-BoardDebugPerson <personId>` makes the device that person, with `<personId>-board` as the personal board unless the backend already has one for them. A `seed-` person opens on their first shared board.

The name, the personal board and the current board in the app group belong to one person. When the device becomes someone else (a debug person, or the sample board making it panth), they're forgotten and read again from the backend. The backend keeps the person's name: the app sends one only when the person types it while making or joining a board.

A launch with `-BoardDebugSeed YES` (the sample board, which the UI tests use) stays offline: nothing is fetched from the backend and nothing is sent, so a UI test never reads or changes the shared dev data. Unit tests stay offline too.

Errors are logged with `Logger.sync`.
