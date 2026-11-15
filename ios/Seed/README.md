# Seed

Owner: APPD-3. Seed drops for DEBUG builds and previews only. Wrap every file in `#if DEBUG`.

`SeedBoard` is the shared board "sf crew" (`sf-crew`): panth, maya, sam and alex (`seed-panth` and so on, colored orange, blue, green and pink), 16 settled drops of every kind with two pinned, and one link still arriving. Client ids are fixed (`5EED0000-0000-4000-8000-0000000000NN`), so the backend's seed of the same board lines up drop for drop. Seeding makes the device panth.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
