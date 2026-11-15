# Ingest

Owner: the share and ingest thread (PAN-5). Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## The one hook

`.dropPipeline()` on the app's root view, inside the `.modelContainer`, is the only thing the app has to call. It runs when the view appears and every time the app returns to the foreground, and it puts `BoardSync` and `BoardsStore` in the environment (see `ios/Sync`).

## Inbox to board

`InboxIngest.run(in:)` reads `Inbox.shared.pending()` oldest first. For each item it copies the payload files to `<app group>/media/<drop id>/`, creates a `Drop` with the item's id, kind, text and link, the person as its author, status `pending` and the default object kind for its source, and saves. It removes the inbox folder only after the save succeeded.

- `Drop.id` is the inbox item's id, so a run that stopped between the save and the removal is finished by the next run without a second drop.
- `Drop.boardId` is the board that was current when the thing was shared, or the current board when the share didn't record one.
- `Drop.mediaPaths` are relative to the app group container, like `media/<drop id>/photo.jpg`.
- A photo's position from its metadata goes in `anchorLatitude` and `anchorLongitude`: it is where the person was, not a place the drop names.
- If a copy or the save fails, the item stays in the inbox and the next run tries again. Errors are logged with `Logger.ingest`.

## Reading on the phone

`DropReader.read(_:in:)` runs before a drop is sent and never blocks the drop from showing. Everything but finding a place runs once per drop. What it finds is kept in `media/<drop id>/read.json`, so a relaunch doesn't read the same drop twice.

- **Typed text:** `TimeWords.parse` sets the countdown or start time, the label and the zone, so "remind me in 1 hr" works with no network.
- **Photos and screenshots:** a 1600 px JPEG for the board and the backend, and a subject cutout from Vision. When Vision finds no subject, or can't run, the drop becomes a polaroid.
- **Video:** four frames, one of them the thumbnail, and the duration.
- **Voice notes:** on-device speech to text. The audio never leaves the phone.
- **PDFs:** the text of the first five pages and a picture of the first page.
- **Links** are read by the backend. The first line of the text that came with the share is passed along as the link's title, without a trailing site name such as "| Spotify" or "- YouTube". `LinkReading` (in `ios/Shared`, so the share extension sends the same hints) reads two kinds on the phone, from the link and that text:
  - **Songs** (Spotify and Apple Music): a page title like "Blinding Lights - song and lyrics by The Weeknd | Spotify" becomes the title "Blinding Lights" and the artist "The Weeknd". The app never listens to anything.
  - **Places** (Apple Maps and Google Maps): the place's name and coordinates from the link go in `title`, `placeName`, `latitude` and `longitude`, and are sent as `hints.linkTitle`, `hints.placeName` and the drop's position, so the backend files it as a place in its neighborhood. A Google link's pin (`!3d…!4d…`) wins over the map's center (`@…`), the center only counts when the link names a place, and a route (`/maps/dir/`) isn't a place. Two cases use the network, in `DropReader.readPlace`, and are tried again on the next send while the drop has no coordinates: a short `maps.app.goo.gl` link is followed with one HEAD request to the full link, and a link with a name but no coordinates is looked up with `PlaceFinder` (MapKit). If either fails the drop is sent without them and the backend reads the link.
