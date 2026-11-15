# Night

Owner: APPD-20. The night view: a dark-only variant of the board beside cards, entered through `NightBoardView`. RootView shows it full screen for `ViewMode.night` (`-view night`, `appdemo://view/night`), with none of the shell's chrome, and scopes the dark color scheme to it.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## For other folders

- `NightBackdrop(palette:isLiving:)` is the slow, grainy mesh gradient behind the night view. It's public to the app, so onboarding can sit on it. Palettes: `.astral` (blue), `.temporal` (orange and teal), `.prism` (pink, blue and amber). It holds still under Reduce Motion or with `isLiving: false`.
- `NightGrain(opacity:)` is the film grain on its own, for any surface.

## What's here

- `NightBoardView`: the screen. Shared boards group by vibe, the personal board by when, pinned first and done last. A drop opens into `NightDetail` with the zoom transition.
- `NightCard(drop:wide:)`: one card per drop, public to the app so other layouts can reuse it. Every card is the same dark surface with a 24pt continuous corner: the picture on top when there is one, then the title, one meta line, the suggestion and who saved it. The only colour on a card comes from its content (a song's surface takes a dark tone sampled from its artwork).
- `NightStyle`: the one type scale (large title, title3, headline, subheadline, caption), spacing, avatar and button sizes. `NightPrimaryButtonStyle` is the solid white primary button; secondary controls are 44pt Liquid Glass.
- `NightHeader`: the board title as a menu that switches boards, a one-line summary, and the everyone or mine switch. Members and the view menu sit in the toolbar.

In DEBUG, `-NightBoard <boardId>` opens on that board, for example `-NightBoard sf-crew` with `-BoardDebugSeed YES`.
