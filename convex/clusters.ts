import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { clusterBoard } from "./lib/vibes";
import { membersByCluster, scheduleSearches } from "./suggestions";

export const recompute = internalMutation({
  args: { boardId: v.string() },
  returns: v.null(),
  handler: async (ctx, { boardId }) => {
    const drops = await ctx.db
      .query("drops")
      .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
      .order("desc")
      .take(300);
    const placed = clusterBoard(
      drops
        .filter((d) => d.status === "processed" && d.zone !== "done" && !d.found?.dismissedAt && (d.vibes?.length ?? 0) > 0)
        .map((d) => ({ clientId: d.clientId, vibes: d.vibes ?? [], capturedAt: d.capturedAt, previousClusterId: d.clusterId, previousClusterLabel: d.clusterLabel, jevClusterId: d.jevClusterId, found: Boolean(d.found) })),
    );
    for (const d of drops) {
      const p = placed.get(d.clientId);
      const next = { clusterId: p?.clusterId, clusterLabel: p?.clusterLabel, neighbors: p?.neighbors ?? [] };
      const same =
        next.clusterId === d.clusterId &&
        next.clusterLabel === d.clusterLabel &&
        JSON.stringify(next.neighbors) === JSON.stringify(d.neighbors ?? []);
      if (!same) await ctx.db.patch("drops", d._id, { ...next, updatedAt: Date.now() });
    }
    await scheduleSearches(ctx, boardId, membersByCluster(drops, (d) => placed.get(d.clientId)?.clusterId));
    return null;
  },
});

export const current = internalQuery({
  args: { boardId: v.string() },
  returns: v.array(v.object({ clusterId: v.string(), clusterLabel: v.string(), size: v.number(), titles: v.array(v.string()) })),
  handler: async (ctx, { boardId }) => {
    const drops = await ctx.db
      .query("drops")
      .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
      .order("desc")
      .take(300);
    const clusters = new Map<string, { clusterId: string; clusterLabel: string; size: number; titles: string[] }>();
    for (const d of drops) {
      if (!d.clusterId || d.found?.dismissedAt) continue;
      const c = clusters.get(d.clusterId) ?? { clusterId: d.clusterId, clusterLabel: d.clusterLabel ?? "", size: 0, titles: [] };
      c.size++;
      const title = d.extraction?.title ?? d.enrichment?.title;
      if (title && c.titles.length < 4) c.titles.push(title.slice(0, 60));
      clusters.set(d.clusterId, c);
    }
    return [...clusters.values()].sort((a, b) => b.size - a.size).slice(0, 8);
  },
});
