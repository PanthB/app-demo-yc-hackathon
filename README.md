https://api.capy.ai/pr-assets/v_sUzzjf_qqaTkjJrI3rzoJbrXS67HJaML2KMOhLM_h4o.mp4

[watch the full demo (demo/demo.mp4)](demo/demo.mp4)

The demo is 2:46 of the real app against the live backend, recorded at real speed with short captions and no audio. It opens on the welcome screen, taps demo and goes through the intro into sf crew. Then it shares a coffee shop from Safari, which waits as a bubble while resona reads it and shows a 'saved to' banner for where it went, a song from Spotify, and a photo from the + button. After that it opens the suggestions tab and scrolls to a small gig at Bottom of the Hill and the movie columbus, goes back to the board, and ends with a TikTok share.

see sf crew live on the web: https://panthb.github.io/app-demo-yc-hackathon/

# Resona

resonate together.

Resona is a native iOS app for saving the things you want to do. Share anything into a board, like a link from Safari, a place from maps, a song from Spotify, a TikTok or a photo, and it gets read for what it is, when you could do it and where, then placed as a physical object: a song becomes a record, a place a postcard, a clip a polaroid. Boards can be shared with friends, sync live between phones, and sort themselves into categories like sad songs or sunny outdoors, with suggestions for each one.

My solo project for The Consumer Mobile Hackathon (YC, San Francisco, November 15, 2026).

Built with Capy, Revyl and Convex.

## what's in the app

Everything below is on `main`.

**night** is the view the app opens in ([`ios/Night`](ios/Night)). It's a dark, slowly moving grain gradient with a frosted header and Liquid Glass controls, and the drops sit on it as plain dark cards whose only color comes from their own picture or artwork. A shared board like sf crew is grouped into categories, like "sad songs, late night" and "sunny outdoors, golden hour", and a personal board by when, with a row of chips that jumps to each group ([#91](https://github.com/PanthB/app-demo-yc-hackathon/pull/91)).

- **the header**: the board title switches boards, starts or joins a shared board, and opens "see full". Under it, a board | suggestions switch flips between the drops and the board's suggestions in place ([#94](https://github.com/PanthB/app-demo-yc-hackathon/pull/94)), and shared boards add everyone or mine.
- **the drop moment**: a new drop waits as a glass bubble in a pending row while it's read, then flies to the group it fits with the screen following it, pops into a card, and the group's title shows a spinner while its suggestions catch up. A banner says which friends' vibes it's closest to, or that it's a new vibe for the crew. After a share, the extension opens Resona and night replays that landing for your own drop ([#91](https://github.com/PanthB/app-demo-yc-hackathon/pull/91), [#100](https://github.com/PanthB/app-demo-yc-hackathon/pull/100), [#103](https://github.com/PanthB/app-demo-yc-hackathon/pull/103), [#104](https://github.com/PanthB/app-demo-yc-hackathon/pull/104), [#106](https://github.com/PanthB/app-demo-yc-hackathon/pull/106)). When a friend's drop arrives, a toast says who added what, like "maya added a song." ([#86](https://github.com/PanthB/app-demo-yc-hackathon/pull/86)).
- **see full** ([`ios/Layouts/BoardWeb.swift`](ios/Layouts/BoardWeb.swift), [#93](https://github.com/PanthB/app-demo-yc-hackathon/pull/93), [#101](https://github.com/PanthB/app-demo-yc-hackathon/pull/101), [#107](https://github.com/PanthB/app-demo-yc-hackathon/pull/107)): the whole board as a calm web of its groups, with links across people and each group's suggestions as satellites you can save, open or dismiss. A group's header opens the web on that group.
- **the streak**: the chip shows the days in a row you dropped something, and the streak sheet shows the crew's run and each friend's, with "invite friends" and the board's code.
- **settings** ([`ios/App/SettingsSheet.swift`](ios/App/SettingsSheet.swift), [#92](https://github.com/PanthB/app-demo-yc-hackathon/pull/92)): the theme, night or scrapbook, the scrapbook's handwriting and lines, and which kinds of suggestions to look for.
- **the add button** holds the camera, which zooms out of the button, and the add menu.

scrapbook is the corkboard ([`ios/Board`](ios/Board)), which turns into the live mood board ([`ios/Clusters`](ios/Clusters)) when a board is arranged by mood. The shell around it ([`ios/App/BoardShell.swift`](ios/App/BoardShell.swift)) still switches to cards and list ([`ios/Glass`](ios/Glass)).

- **first run** ([`ios/Onboarding`](ios/Onboarding)): "welcome" draws itself over a fan of example drops, then "demo" joins sf crew while a three-step guide plays, and "start fresh" offers continue with apple, continue as a guest, or the demo. It lands in night.
- **share from any app** ([`ios/ShareExtension`](ios/ShareExtension)): links, photos, videos, audio, text and PDFs. The drop is saved to the app group right away with a short note naming the board, and the app does the slow work after ([`ios/Ingest`](ios/Ingest)).
- **add inside the app** ([`ios/Sync/AddMenu.swift`](ios/Sync/AddMenu.swift), [`ios/Camera`](ios/Camera)): take a photo, pick a photo, paste a link or write a note. The in-app camera writes each photo to the inbox the moment it's taken and shows it flying onto the board.
- **read on the phone first** ([`ios/Ingest/Reading`](ios/Ingest/Reading)): Spotify, Apple Music, TikTok, Instagram, YouTube, Google Maps and Apple Maps links give their title, artist or place; videos give a few frames; voice notes are transcribed with Speech; PDFs give their text.
- **read and placed by the backend** ([`convex/pipeline.ts`](convex/pipeline.ts)): each drop is read for kind, place, time and vibe words, then the decider picks its type, its section (now, tonight, this weekend, someday or vibes), its object (record, postcard, polaroid, cutout, slip, sticky or stub) and what it connects to. Songs get genre and length from Deezer, and TikTok and Instagram links get their captions through ScrapeCreators ([`convex/lib/enrich.ts`](convex/lib/enrich.ts)). If a step fails, the drop stays on the board as a plain object that still works.
- **moods** ([`convex/lib/vibes.ts`](convex/lib/vibes.ts), [`convex/clusters.ts`](convex/clusters.ts)): every drop is read for the kind of thing it is (sad songs, food spots, sunny outdoors, thrillers and so on) and its vibes, and a board's drops are grouped into labeled categories like "sad songs, late night" or "food & drinks, late night", with the kind weighted most ([#102](https://github.com/PanthB/app-demo-yc-hackathon/pull/102), [#105](https://github.com/PanthB/app-demo-yc-hackathon/pull/105)). Clusters are recomputed after every drop, with up to two neighbors per drop. On the phone, the shared cluster engine keeps each group's identity through re-clusters and animates new drops into place; groups are set apart by space, and the lines between related drops are off unless you turn them on ([`ios/Clusters`](ios/Clusters)).
- **arrange and filter** ([`ios/App/BoardShell.swift`](ios/App/BoardShell.swift)): the title menu switches boards, starts a shared board, joins with a code and invites friends; the arrange menu picks "by when" or "by mood" per board; shared boards add everyone or mine. When a friend's drop arrives, a glass toast says who added what, like "maya added a song."
- **suggestions** ([`convex/suggestions.ts`](convex/suggestions.ts), [`ios/Glass/SuggestionsFeed.swift`](ios/Glass/SuggestionsFeed.swift)): when a cluster changes, the backend searches the web for events, songs, things to watch and places that fit it, and night's suggestions tab shows them grouped by cluster, each with a picture and a pill naming the vibe it fits. You can save one to the board, dismiss it or open it, and anyone on the board can refresh them by hand; a small red dot on the tab means there are suggestions you haven't opened yet ([#109](https://github.com/PanthB/app-demo-yc-hackathon/pull/109), [#82](https://github.com/PanthB/app-demo-yc-hackathon/pull/82), [#90](https://github.com/PanthB/app-demo-yc-hackathon/pull/90)). An hourly cron catches clusters that changed ([`convex/crons.ts`](convex/crons.ts)).
- **open, pin, move, done**: a drop opens into its detail with the native zoom transition, and its menu pins it, moves it to another section, marks it done, puts it back or opens its link. Each change goes to Convex ([`ios/Sync/BoardSync.swift`](ios/Sync/BoardSync.swift)).
- **shared boards** ([`convex/boards.ts`](convex/boards.ts), [`ios/Sync`](ios/Sync)): a board has an invite code and an `appdemo://join/<code>` link, members get a color, every drop shows who saved it, and `boards:leave` takes a person off a board.
- **sign in** ([`ios/Auth`](ios/Auth), [`convex/people.ts`](convex/people.ts)): Sign in with Apple links the account to its person through `people:link`, so a second phone gets the same boards back. A guest is an anonymous person id.
- **sf crew**: the demo board, seeded with fifteen real SF places, clips and songs from four friends, with real photos and album covers ([`convex/seed.ts`](convex/seed.ts), [`ios/Seed`](ios/Seed)).

### on the web

[`web/`](web) is a small page (Vite and the Convex browser client) published from the `gh-pages` branch. It subscribes to `drops:list` and `suggestions:list` on the same deployment, so it shows sf crew live, grouped by mood, with each group's suggestions and their reasons. "try it" makes you a guest board where you can paste a link.

### what's next

A mood home layout is in progress as a prototype on the branch [`capy/layouts-web-wip`](https://github.com/PanthB/app-demo-yc-hackathon/tree/capy/layouts-web-wip). It's not on `main`.

## built with capy, revyl and convex

### convex

Convex is the whole backend: the database, the functions, the file storage, the scheduler, a cron and the live sync to the phones and the web page. The dev deployment is `adorable-coyote-696`.

- **tables** ([`convex/schema.ts`](convex/schema.ts)): `people`, `boards`, `members`, `drops` (with a full-text search index used to find related drops), `suggestions` and `suggestionSearches` for suggestions, `openaiCalls` and `openaiTotals` for spend, plus `eventSearches` and `moments` from earlier versions.
- **functions**: [`boards.ts`](convex/boards.ts) (`create`, `join`, `leave`, `mine`), [`drops.ts`](convex/drops.ts) (`submit`, `list`, `setPinned`, `setZone`, `retry`), [`people.ts`](convex/people.ts) (`upsert`, `link`), [`pipeline.ts`](convex/pipeline.ts) (the scheduled action that enriches, reads and decides each drop), [`clusters.ts`](convex/clusters.ts) (`recompute`), [`suggestions.ts`](convex/suggestions.ts) (`list`, `save`, `dismiss` and the search), [`spend.ts`](convex/spend.ts) (`openai`, `recordOpenAI`), [`files.ts`](convex/files.ts) (image uploads) and [`seed.ts`](convex/seed.ts).
- **live sync**: the app subscribes to `boards:mine` and `drops:list` through [ConvexMobile](https://github.com/convex/convex-swift), so a friend's drop shows up on every phone on the board as soon as it's saved, and moves when the backend has read it ([`ios/Sync/BoardsStore.swift`](ios/Sync/BoardsStore.swift), [`ios/Sync/BoardSync.swift`](ios/Sync/BoardSync.swift)).
- **models** ([`convex/lib/models.ts`](convex/lib/models.ts)): every model call goes to OpenAI. The reader (Chat Completions) and the decider (the Decisions API) run on `gpt-6-luna`, and suggestions run on `gpt-6.1-terra` with web search through the Responses API. If `SUPERMEMORY_API_KEY` is set, related drops are found through Supermemory, and otherwise through Convex's full-text search.
- **spending cap**: before every OpenAI call the backend adds up what's been spent and refuses once it reaches the budget. The cap defaults to $100 and is set by `OPENAI_BUDGET_USD` in the Convex env ([`convex/lib/models.ts`](convex/lib/models.ts)); every call's cost, web searches included, is recorded in `openaiCalls` ([`convex/spend.ts`](convex/spend.ts)). When there's no key, the budget is spent or a call fails, built-in rules read and place the drop instead ([`convex/lib/rules.ts`](convex/lib/rules.ts)).
- **keys**: `OPENAI_API_KEY` lives only in the Convex deployment's environment. The app and the web page never hold a key.

### revyl

The Capy agents' cloud machines have no Xcode, so they built the iOS app on Revyl's cloud build runners (Xcode 27) and drove it on Revyl's cloud iPhones, with Panth's Mac (Xcode 26.6) as a second compile check.

- [`.revyl/config.yaml`](.revyl/config.yaml): the build recipe. It installs XcodeGen, runs `xcodegen generate`, builds the `AppDemo` scheme for the simulator and uploads the app.
- [`.revyl/tests`](.revyl/tests): twenty plain-English device tests.
  - flows: `phase1-1-share-into-board`, `phase1-2-drop-lands-on-board`, `phase1-3-drag-between-zones`, `phase1-4-tag-flip`, `phase1-5-countdown`, `phase1-6a-nearby-suggestion`, `phase1-6b-time-sections`
  - views: `views-1-switch`, `views-2-pin`, `views-3-filter-mine`, `views-4-join-by-code`
  - integration gate: `gate-join-by-link`, `gate-night-streaks`, `gate-pin-move-done-undo`, `gate-share-from-safari`, `gate-two-phone-live`, `gate-board-filter-cards-list`, `gate-night-start-board-add-note`, `gate-friend-drop-arrives-live`, `gate-relaunch-keeps-board`
- **integration gate**: in the evening, a tester thread ran rounds against `main` between merges, and its specs became Revyl tests: five from round 1 in [#57](https://github.com/PanthB/app-demo-yc-hackathon/pull/57) and four from round 2 in [#73](https://github.com/PanthB/app-demo-yc-hackathon/pull/73), with a helper that makes qa boards and acts as a second person on the backend ([`.revyl/scripts/qa_board.py`](.revyl/scripts/qa_board.py)). Fixes for what the rounds found are in [#60](https://github.com/PanthB/app-demo-yc-hackathon/pull/60), [#65](https://github.com/PanthB/app-demo-yc-hackathon/pull/65) and [#67](https://github.com/PanthB/app-demo-yc-hackathon/pull/67).
- [`.revyl/evidence`](.revyl/evidence): runs on cloud iPhones with their report links and screenshots. On `main` at 70f40e0, joining sf crew by link and a Safari share landing as "tartine bakery" passed, and the share-note check failed because the note closed before the check, which [#55](https://github.com/PanthB/app-demo-yc-hackathon/pull/55) fixed with a DEBUG hold. Runs that passed without doing the work are listed as not counting.
- 34 of the 73 merged pull requests mention Revyl in their body, for example [#2](https://github.com/PanthB/app-demo-yc-hackathon/pull/2) (the first build used on a cloud iPhone), [#15](https://github.com/PanthB/app-demo-yc-hackathon/pull/15) and [#16](https://github.com/PanthB/app-demo-yc-hackathon/pull/16) (sharing from Safari and Photos on a cloud iPhone), [#26](https://github.com/PanthB/app-demo-yc-hackathon/pull/26) (sync) and [#48](https://github.com/PanthB/app-demo-yc-hackathon/pull/48) (the main runs above).

### capy

I built the app solo, directing a crew of Capy agent threads through one Captain thread. Each thread owned one folder (`convex/`, `.revyl/`, `ios/Board`, `ios/Glass`, `ios/Sync` and the share extension, `ios/Night`, `ios/Clusters`, `ios/Onboarding`, `ios/Camera`, `web/` and so on), opened its own pull requests, and showed its evidence in the body. The Captain merged each one once it was ready.

- 73 pull requests merged on `main` between 18:43 and 22:52 UTC on November 15, and 64 of them link back to the Capy thread that opened them, eleven threads in all.
- All 179 non-merge commits on `main` carry a `Co-authored-by: capy-ai[bot]` trailer.
- A representative set:
  - [#1](https://github.com/PanthB/app-demo-yc-hackathon/pull/1) Convex backend and build log
  - [#3](https://github.com/PanthB/app-demo-yc-hackathon/pull/3) Revyl config, skills and device tests
  - [#5](https://github.com/PanthB/app-demo-yc-hackathon/pull/5) the drop pipeline
  - [#15](https://github.com/PanthB/app-demo-yc-hackathon/pull/15) the share extension
  - [#26](https://github.com/PanthB/app-demo-yc-hackathon/pull/26) live sync with Convex
  - [#31](https://github.com/PanthB/app-demo-yc-hackathon/pull/31) OpenAI with a spending cap
  - [#32](https://github.com/PanthB/app-demo-yc-hackathon/pull/32) the night view
  - [#44](https://github.com/PanthB/app-demo-yc-hackathon/pull/44) the cluster engine and live mood board
  - [#45](https://github.com/PanthB/app-demo-yc-hackathon/pull/45) the in-app camera
  - [#46](https://github.com/PanthB/app-demo-yc-hackathon/pull/46) first run and Sign in with Apple
  - [#53](https://github.com/PanthB/app-demo-yc-hackathon/pull/53) one glass shell for every view
  - [#59](https://github.com/PanthB/app-demo-yc-hackathon/pull/59) and [#65](https://github.com/PanthB/app-demo-yc-hackathon/pull/65) suggestions, in the backend and the feed
  - [#68](https://github.com/PanthB/app-demo-yc-hackathon/pull/68) night as the default
  - [#69](https://github.com/PanthB/app-demo-yc-hackathon/pull/69) the live web page

[`hackathon.md`](hackathon.md) is the build log.

## run it

### iOS app

You need Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). Only the spec, [`ios/project.yml`](ios/project.yml), is committed.

```sh
cd ios
xcodegen generate
open AppDemo.xcodeproj
```

Pick the `AppDemo` scheme and run it on an iOS 26 Simulator. The app talks to the deployment named by `CONVEX_URL` in [`ios/Config/AppDemo.xcconfig`](ios/Config/AppDemo.xcconfig); point it at your own deployment if you run your own backend. In a Debug build, the launch argument `-BoardDebugSeed YES` loads the sample boards offline. [`ios/README.md`](ios/README.md) has the targets, the links and the other debug switches.

### backend

```sh
npm install
npx convex dev
```

`npx convex dev` signs you in, creates your own dev deployment, pushes the functions in `convex/` and keeps watching. For the models, set the key in that deployment's environment, not in the repo:

```sh
npx convex env set OPENAI_API_KEY <your key>
```

Without it, every drop is read and placed by the built-in rules, and there are no suggestions. `npm run seed` adds the demo boards, and `npm run lint` runs the typecheck and ESLint.

### web page

```sh
cd web
npm install
npm run dev
```

It reads the deployment set in [`web/src/main.js`](web/src/main.js).
