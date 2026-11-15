# Glass

Owner: APPD-12. The cards view and the standard item every view shares, drawn with system text styles, system backgrounds and Apple's Liquid Glass. They read the same `Drop` records as the board view in `ios/Board`.

- `CardsView(sections:namespace:select:)` is the default view: sections from `DropSection`, pinned drops as a row of compact cells, every other section as a two-column masonry grid, and done collapsed at the end. It owns its scroll view. A long press opens a context menu that calls `dropActions` (pin, mark done, put it back, move to, open link). Every item carries `matchedTransitionSource` and `matchedGeometryEffect` with the drop's id in the namespace it's given.
- `DropCard` is the standard card: the preview, the kind pill at the top leading corner, the title, one meta line (when, then where), the suggestion when there is one, and who saved it. A drop with a picture shows it full width. A drop without one is drawn on the card's own surface: a note's words, a reminder's live countdown, an event's date, a voice note's waveform and length.
- `KindPill`, `PinBadge` and `ClipBadge` are the only glass on a card (`glassEffect` in a capsule). `PersonAvatar` is the saver's initial on their `authorColor`. `SuggestionLine` is the one line the app says about a drop, in the accent color.
- `DropKind` works the kind out from fields `Drop` already has: a due time makes a reminder, anything that plays (a video, or a TikTok, YouTube, Vimeo or Instagram reel link) is a clip, then what the reader found (song, event, place), then the source (photo, voice, link, note).
- `Masonry` is the pure column maths: each card goes to the shorter column, and a section of up to 12 cards is split so the two columns end as level as they can while the first card stays top leading.
- `GlassBoardRoot` is a stand-in host that `RootView` shows for the cards and list views until the shell lands.

Rules this folder follows: a card is opaque content with a 22pt continuous corner, no tilt and no glow. Text is SF Pro in system text styles, so Dynamic Type works, and numbers use monospaced digits. The accent color (`.tint`) marks what is live: countdowns, the date on an event, a waveform and the suggestion. A person's color appears only on their avatar.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build. `ios/UITests/CardsViewUITests.swift` drives this view, and it runs only once `project.yml` has a UI test target.
