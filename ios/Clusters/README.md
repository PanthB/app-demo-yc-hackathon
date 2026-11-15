# Clusters

Owner: APPD-16. The board arranged by mood: drops in soft clusters with strings between close neighbors, entered through `ClusterBoardView`.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

- `ClusterBoardView(drops:namespace:filter:me:select:)` is the seam. Hand it one shared board's drops and the shell's namespace, and put a `BoardClock` in the environment. It draws no glass controls.
- The board scrolls down: pinned first, then one labeled cluster per `clusterId` (the cluster whose oldest drop is oldest comes first, so a growing cluster never reshuffles the ones above it), then "on their own" for drops with no cluster, then done.
- `ClusterLayout` is pure geometry: rows packed by neighbors, tilt up to 1.4°, at most two strings per drop and one string between any two clusters. The same drops always give the same layout.
- A new drop lands where you're looking, waits until the backend has read it, then flies into its cluster while the cluster makes room.
- Each object is a `matchedTransitionSource` in the shell's namespace for the zoom into detail.

DEBUG only: `ClusterPlayground` shows the seeded sf crew board. Launch arguments: `-ClusterDebugCluster <clusterId>` scrolls to a cluster, `-ClusterDebugArrival YES` plays a new drop arriving, and `-ClusterDebugCopies 2` doubles the board to 30 drops.
