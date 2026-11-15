# Hackathon log

- **Project:** app-demo-yc-hackathon
- **Event:** The Consumer Mobile Hackathon
- **What it does:** A native iOS board where anything you share lands as an object, and the backend reads it, places it by when you can act on it (now, tonight, this weekend, someday or vibes), and ties related drops together.
- **Live app:** not deployed
- **Repo:** private
- **Frontend:** not deployed
- **Convex deployment:** https://adorable-coyote-696.convex.cloud
- **Components:** none
- **Convex features:** schema, tables, indexes, full-text search, queries, mutations, actions, scheduled functions, file storage, realtime subscriptions
- **Auth:** none
- **AI models:** typesafe/jev-1.14, deepseek/deepseek-v4.1-flash-1017 (through OpenRouter, wired in code; no key set yet)
- **Started:** 2026-11-15T18:36:06Z
- **Last updated:** 2026-11-15T19:03:39Z

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
