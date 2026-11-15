# Ingest

Owner: the share and ingest thread (PAN-5). Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## The one hook

`.dropPipeline()` on the app's root view, inside the `.modelContainer`, is the only thing the app has to call. It runs when the view appears and every time the app returns to the foreground.

## Inbox to board

`InboxIngest.run(in:)` reads `Inbox.shared.pending()` oldest first. For each item it copies the payload files to `<app group>/media/<drop id>/`, creates a `Drop` with the item's id, kind, text and link, status `pending` and the default object kind for its source, and saves. It removes the inbox folder only after the save succeeded.

- `Drop.id` is the inbox item's id, so a run that stopped between the save and the removal is finished by the next run without a second drop.
- `Drop.mediaPaths` are relative to the app group container, like `media/<drop id>/photo.jpg`.
- A photo's position from its metadata goes in `anchorLatitude` and `anchorLongitude`: it is where the person was, not a place the drop names.
- If a copy or the save fails, the item stays in the inbox and the next run tries again. Errors are logged with `Logger.ingest`.
