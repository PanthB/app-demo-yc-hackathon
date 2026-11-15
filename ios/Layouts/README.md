# Layouts

Owner: APPD-22. Board layouts that are not a scroll of cards. Each one takes the board's drops and a namespace, and positions every drop by something a person can read.

- `ConstellationView`: the web. Drops are nodes in the night sky, grouped by vibe (or by time on a personal board), with the newest or soonest in the middle of each group and lines between neighbors. Tap a drop to see why it is linked, pinch out to collapse to the groups.
- `OrbitView`: the time dial. On a personal board it reads like a 24-hour clock: rings are now, tonight, this weekend and someday, the angle is the time of day, and the hand is now. On a shared board each friend has a slice and the rings are today, this week and earlier.
- `NightMapView`: the night map. Places glow where they are in San Francisco, in the color of whoever saved them, and songs and clips sit beside the place they go with (a neighbor first, then a place with the same vibe).

In DEBUG, `-LayoutLab web|orbit|map` with `-LayoutBoard sf-crew` and `-BoardDebugSeed YES` opens `LayoutLab`, once RootView hosts it.
