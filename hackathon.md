# Hackathon log

- **Project:** app-demo-yc-hackathon
- **Event:** The Consumer Mobile Hackathon
- **What it does:** A native iOS app where anything you share, like a place, a clip, a song or a note, lands on your own board or a board shared with friends. The backend reads each drop, places it by when you can act on it (now, tonight, this weekend, someday or vibes), ties related drops together and groups a shared board by vibe.
- **Live app:** not deployed
- **Repo:** private
- **Frontend:** not deployed
- **Convex deployment:** https://adorable-coyote-696.convex.cloud
- **Components:** none
- **Convex features:** schema, tables, indexes, full-text search, queries, mutations, actions, internal functions, scheduled functions, file storage, realtime subscriptions, typed environment variables, auth (OIDC)
- **Auth:** sign-in with Apple or Google links an account to its person; access checks are next, so functions still trust the person id the app sends
- **AI models:** gpt-6-luna through OpenAI only: Chat Completions reads drops and the Decisions API decides, under a $20 cap
- **Started:** 2026-11-15T18:36:06Z
- **Last updated:** 2026-11-15T21:16:00Z

## Log

### 2026-11-15 - 892b8fd
Set up the Convex backend: a `moments` table (text, author, createdAt) with an
index on createdAt, a query that lists the newest 100 moments first, and a
mutation that adds one, pushed to the dev deployment. Convex features: schema,
indexes, query, mutation (`convex/schema.ts`, `convex/moments.ts`).

### 2026-11-15 - 6b83bcc
Added the native SwiftUI iOS app: an XcodeGen spec for iOS 17, the ConvexMobile
Swift client with the deployment URL read from an xcconfig, a screen that
subscribes live to the moments query, and a composer that calls the add
mutation, with os_log error logging. Convex features: realtime subscription from
Swift (`ios/project.yml`, `ios/AppDemo/MomentsView.swift`,
`ios/AppDemo/ComposerView.swift`).

### 2026-11-15 - 1c06721
Laid out the iOS skeleton for the board: a share extension embedded in the app
with a shared app group, a SwiftData drop model with the shared vocabulary, the
on-device inbox format the share extension writes to, and a time-word parser,
with unit tests for the inbox and the parser (`ios/ShareExtension/ShareViewController.swift`,
`ios/Shared/Drop.swift`, `ios/Shared/Inbox.swift`, `ios/Shared/TimeWords.swift`,
`ios/Tests/`).

### 2026-11-15 - c98cee0
Built the drop pipeline. Drops are stored per board and are idempotent on the
device's id. The app subscribes to a live list, and a zone the person sets is never
overridden. Images upload to file storage. A scheduled action enriches links over
HTTP, reads each drop, finds related drops through a full-text search index, and
decides type, zone, object and connections with Jev through OpenRouter. Each step
falls back to built-in rules when a key is missing, so no drop is lost. A board
mode action picks planning or wandering. Convex features: schema, indexes,
full-text search, queries, mutations, actions, scheduled functions, file storage
(`convex/schema.ts`, `convex/drops.ts`, `convex/pipeline.ts`, `convex/board.ts`,
`convex/files.ts`).

### 2026-11-15 - f202abb
Read each drop with Clairic, OpenRouter's structured extraction model, with a
vision model standing in when Clairic fails or gets an image format it can't
read. Fields Clairic is unsure of are left empty (`convex/lib/models.ts`,
`convex/pipeline.ts`).

### 2026-11-15 - 1f19f71
Built the iOS board: a paper and glass look switch behind an `appdemo://` deep
link, the paper corkboard in SwiftUI with zones, seven object kinds, tags, pins,
string and a vibes envelope, and an SVG kit asset catalog with the app icon
(`ios/Board/`, `ios/Assets/`).

### 2026-11-15 - 33d908c
Added the Revyl project config and end-to-end tests for the core flow and the
views, run on cloud iPhones (`.revyl/`).

### 2026-11-15 - 78e0efb
Added shared boards. A person is an id plus a name with a personal board.
Boards have invite codes, members get colors in join order, drops can be
pinned, and the list carries a suggestion line such as "maya saved this too."
worked out by rules when it is read. Existing drops moved from `personId` to
`authorId` through a widen, backfill and deploy. Convex features: schema,
indexes, queries, mutations (`convex/boards.ts`, `convex/people.ts`,
`convex/drops.ts`, `convex/lib/suggest.ts`).

### 2026-11-15 - 045985e
The share extension saves shares to an on-device inbox and confirms with a
paper card, and the app moves inbox drops onto the board and syncs them
(`ios/ShareExtension/`, `ios/Ingest/`).

### 2026-11-15 - e8aadae
Fixed the rules reader: Instagram captions without the post date, no song
lengths or bare "morning" read as times, and worded countdowns such as "in
thirty minutes" (`convex/lib/rules.ts`, `convex/lib/enrich.ts`).

### 2026-11-15 - 0c36da1
Built the shared-board model in the app with three views of the same drops
(list, cards and board), sections, drop actions and a DEBUG seed, then the
cards view with a standard drop card, a play badge and length on clips and
square song artwork. Added the Clusters, Onboarding and Auth folders and a UI
test target (`ios/App/`, `ios/Shared/`, `ios/Glass/`, `ios/Seed/`).

### 2026-11-15 - bb8e00b
Gave every drop vibes from a fixed vocabulary (mood, time of day, setting,
neighborhood, genre and energy), soft clusters with labels and up to two
neighbors, recomputed after each drop. Songs get genre, tempo and length from
Deezer's public API. Convex features: internal mutations and queries, scheduled
functions (`convex/lib/vibes.ts`, `convex/clusters.ts`, `convex/lib/enrich.ts`).

### 2026-11-15 - 179d45f
Read TikTok and Instagram captions, authors and clip lengths through
ScrapeCreators, asking for a cached result up to 30 days old and never the
media, with page tags as the fallback (`convex/lib/enrich.ts`).

### 2026-11-15 - ae5218e
The app shows the mood fields and by-vibe sections, with a reseeded DEBUG
board (`ios/Seed/`, `ios/Shared/`).

### 2026-11-15 - 201b00a
Moved every model call to free OpenRouter models: particle-ai/particle-1:free
reads drops, with nvidia/nemotron-3.5-super-vl:free as backup, and
perplexity/pplx-decider-v1.3:free decides. A song link skips the reader. Clairic
and Jev stay one env change away (`convex/lib/models.ts`, `convex/pipeline.ts`,
`convex/board.ts`).

### 2026-11-15 - 0b2c6c8
Added the Night and Camera folders and a night view mode, and a Revyl test
that shares a Google Maps place from Safari (`ios/`, `.revyl/`).

### 2026-11-15 - 078aa6e
Put the reader and decider on OpenAI's gpt-6-luna, with the decider on the
Decisions API. `MODEL_PROFILE` picks the order: `test` keeps the free models
first and overflows to OpenAI on a 429, and `demo` puts OpenAI first. Rules come
last. Every OpenAI call's cost is recorded, and calls stop at a $20 cap. A drop
costs about $0.0004. Convex features: tables, internal queries and mutations
(`convex/lib/models.ts`, `convex/spend.ts`, `convex/schema.ts`).

### 2026-11-15 - fa67434
Seeded the demo boards on the dev deployment. "sf crew" gets fifteen real SF
places, clips and songs from four friends, read by the models, and panth's own
board gets fourteen drops placed by time. Rerunning the seed changes nothing
that is already seeded. A drop with a time now takes its zone from that time,
so "saturday 7pm" saved on a Sunday lands in this weekend. Convex features:
internal actions and mutations, scheduled functions, file storage
(`convex/seed.ts`, `scripts/seed.mjs`, `convex/pipeline.ts`).

### 2026-11-15 - 70f40e0
Seeded "sf crew" in its stated state: fifteen drops already read, three vibe
clusters with their labels, two connected pairs and two pins, the same on every
run. TikTok, Instagram and YouTube links always read as clips, a drop with no
time is only asked "someday or vibes", and clusters group by feel and time of
day across kinds of drop (`convex/seed.ts`, `convex/lib/vibes.ts`,
`convex/lib/rules.ts`, `convex/pipeline.ts`).

### 2026-11-15 - a5f0002
Sign-in with Apple or Google links an account to its person: OIDC providers in
`convex/auth.config.ts` and a `people:link` mutation, so a second phone gets
the same person back. Access checks are next: functions still trust the person
id the app sends. Convex features: auth config, indexes (`convex/auth.config.ts`,
`convex/people.ts`, `convex/schema.ts`).

### 2026-11-15 - 09ee258
Dropped OpenRouter. The reader and decider run only on OpenAI's gpt-6-luna under
the $20 cap, with rules as the fallback. A clip's title now comes from its
caption instead of the share sheet's link title (`convex/lib/models.ts`,
`convex/pipeline.ts`).
