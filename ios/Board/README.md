# Board

Owner: APPD-3. The paper look: the corkboard scene in the sunny mood, the seven paper objects, pins, tape, tags and string, the vibes envelope and the done pocket. Built from `handoffs/APPD-5/tokens.md` (revision 2) and the APPD-7 review in the Captain's drive.

- `PaperBoardRoot` is the entry point `RootView` shows for the paper look. It lays the board out with `BoardClock.now` and animates every move on the mode-shift spring.
- `CorkboardLayout` places zone labels, objects (staggered left and right inside each band), tags, pins and string, and the footer with the done pocket and the vibes envelope. It is pure geometry, so the same drop always lands in the same spot.
- `PaperObjects` draws each object kind. `BoardParts` draws pins, tape, the when tag, zone labels and the corner furniture. `Mood` holds the sunny tokens. `CorkSurface` is the speckled cork.

Rules this folder follows: text on cork is ink, the hand font is only for what the app writes (zone labels, corner labels, the empty-board note), the person's words are SF Pro Rounded, and times are SF Mono on a paper tag. Tape means the app hasn't placed a drop or isn't sure; a ringed pin means the person put it there.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.
