# Seed

Owner: APPD-3. Seed drops for DEBUG builds and previews only. Wrap every file in `#if DEBUG`.

`SeedBoard` loads two boards. "my board" (`seed-panth-board`) is panth's time-based set, 14 settled drops and one link still arriving, with two pinned. "sf crew" (`sf-crew`) is shared by panth, maya, sam and alex (`seed-panth` and so on, colored orange, blue, green and pink): 15 places, clips and songs from real links in three clusters, with two pinned. Client ids are fixed (`5EED0001-…` and `5EED0002-…`), so the backend's seed lines up drop for drop. Seeding makes the device panth. The images are stand-ins from the image tool.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
