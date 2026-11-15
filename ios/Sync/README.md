# Sync

Owner: the share and ingest thread (PAN-5). The Convex sync client. It uses the one `convex` client from `ios/App/Convex.swift`, and it applies pipeline zones through `Drop.applyDecidedZone(_:unsure:)` so a zone the person set is never overridden.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
