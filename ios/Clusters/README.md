# Clusters

Owner: APPD-16. The board arranged by mood: drops in soft clusters set apart by spacing, entered through `ClusterBoardView`. Strings between close neighbors show only while `@AppStorage("BoardLines")` is on, and it's off by default.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## the shared engine

Pure Swift, no views. Recompute it whenever the drops change. APPD-22's constellation builds on it, so any change to these signatures goes through the Captain first.

- `ClusterSnapshot(drops:following:)` says who sits with whom. `groups` come in board order: pinned, then clusters by their oldest drop, then "on their own", then done. Each group has an `id` that stays the same through re-clusters, merges and relabels while most of its members stay, plus a `shelf`, a `label`, and `members` (linked drops next to each other, oldest first). `pairs` are the strings, at most two per drop and at most one between any two clusters, each with the backend's reason. Pass the previous snapshot as `following` to keep ids stable.
- `snapshot.changes(since:)` lists what happened as `ClusterChange`: `arrived`, `moved`, `formed`, `merged`, `split`, `relabeled` and `dissolved`.
- `ClusterMotion` is the shared motion: `drift` for groups and drops moving to new places, `makeRoom` for a cluster opening a gap, and `delays(for:)`, which staggers moves so several read one after another.
- `ClusterField(snapshot, size:, following:)` places groups on a plane for renderers that aren't a vertical scroll. Each group gets a center in a unit square and a radius in points, and each drop gets an offset from its center (`position(of:)` adds them up). Centers start where they were last time, so an existing group drifts a little when another forms instead of jumping.
- `ClusterLayout(snapshot, width:, member:)` gives this board's positions: a vertical stack with tilt up to 1.4°, and strings that start at each object's edge and bend around labels, tags and other objects. A string that can't get through cleanly isn't drawn.

## the board

`ClusterBoardView(drops:namespace:filter:me:select:)` is the seam. Hand it one shared board's drops and the shell's namespace, and put a `BoardClock` in the environment. It draws no glass controls.

- **A new drop.** It lands where you're looking and floats there, even while you scroll. Once it has been read it flies into its cluster while the cluster makes room. Several drops landing together fan out and leave 0.45s apart.
- **Groups changing.** A relabel morphs the label in place, a merged group's label drifts into the group that took it, and a split buds off its parent. Drops move one after another.
- **Following.** When you aren't touching the board, it follows your own drop to wherever it lands. A friend's drop leaves toward its cluster while the board stays where you are, and merges and splits never move it.
- **Font and dark mode.** Labels use the handwriting font while `Mood.handwritingKey` is on, and the upright rounded font when it's off. In dark mode the cork dims and the paper stays paper.

DEBUG only: `ClusterPlayground` shows the seeded sf crew board. Launch arguments:
- `-ClusterDebugCluster <clusterId>` scrolls to a cluster.
- `-ClusterDebugArrival YES` plays maya's drop arriving.
- `-ClusterDebugLive YES` drips the board in one friend's drop at a time, so groups form, merge, split and relabel.
- `-ClusterDebugCopies 2` doubles the board to 30 drops.
