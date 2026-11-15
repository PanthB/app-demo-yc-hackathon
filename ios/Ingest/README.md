# Ingest

Owner: the share and ingest thread (PAN-5). Reads the inbox (`Inbox.shared.pending()` in `ios/Shared/Inbox.swift`), creates `Drop` records, runs the on-device readers, and removes inbox items once they are safely on the board.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
