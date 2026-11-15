import { ConvexError, v } from "convex/values";
import {
  internalMutation,
  internalQuery,
  mutation,
  query,
  type MutationCtx,
  type QueryCtx,
} from "./_generated/server";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { membersOf, personById } from "./boards";
import { nameLabel, nounFor, sameThing, sitsWithLine, socialLine } from "./lib/suggest";
import {
  decision,
  dropDoc,
  dropView,
  enrichment,
  extraction,
  nullable,
  pipeline,
  sourceKind,
  zone,
  type Pipeline,
} from "./model";

export const FOUND_NAME = "found for you";

const freshPipeline = (): Pipeline => ({
  enrich: { ran: "pending" },
  extract: { ran: "pending" },
  remember: { ran: "pending" },
  decide: { ran: "pending" },
  connect: { ran: "pending" },
});

const hintsArg = v.object({
  linkTitle: nullable(v.string()),
  artist: nullable(v.string()),
  transcript: nullable(v.string()),
  pdfText: nullable(v.string()),
  placeName: nullable(v.string()),
  dueAt: nullable(v.number()),
});

const withoutNulls = <T extends Record<string, unknown>>(o: T) =>
  Object.fromEntries(Object.entries(o).filter(([, x]) => x !== null)) as {
    [K in keyof T]: Exclude<T[K], null>;
  };

async function byClientId(ctx: QueryCtx, boardId: string, clientId: string) {
  const drop = await ctx.db
    .query("drops")
    .withIndex("by_clientId", (q) => q.eq("clientId", clientId))
    .unique();
  return drop?.boardId === boardId ? drop : null;
}

async function toView(
  ctx: QueryCtx,
  d: Doc<"drops">,
  dropsByClientId: Map<string, Doc<"drops">>,
  names: Map<string, string>,
  colors: Map<string, string>,
) {
  const urls = await Promise.all(d.imageIds.map((id) => ctx.storage.getUrl(id)));
  const imageUrls = urls.filter((u): u is string => u !== null);
  const fromOthers = d.relatedClientIds
    .map((id) => dropsByClientId.get(id))
    .filter((o): o is Doc<"drops"> => o !== undefined && o.authorId !== d.authorId);
  const social = fromOthers.length
    ? socialLine(
        fromOthers.map((o) => nameLabel(names.get(o.authorId))),
        fromOthers.some((o) => sameThing(o, d)),
      )
    : undefined;
  const neighbors = d.neighbors ?? [];
  const near = neighbors
    .map((n) => ({ n, drop: dropsByClientId.get(n.clientId) }))
    .find((x) => x.drop !== undefined && x.drop.authorId !== d.authorId);
  const sitsWith = near?.drop ? sitsWithLine(nameLabel(names.get(near.drop.authorId)), nounFor(near.drop), near.n.reason) : undefined;
  return {
    ...d,
    title: d.extraction?.title ?? d.hints?.linkTitle ?? d.enrichment?.title,
    thumbnailUrl: imageUrls[0] ?? d.enrichment?.thumbnailUrl,
    imageUrls,
    authorName: d.found ? FOUND_NAME : names.get(d.authorId),
    authorColor: colors.get(d.authorId),
    suggestion: d.suggestion ?? social ?? sitsWith,
    vibes: d.vibes ?? [],
    neighbors,
  };
}

async function schedule(ctx: MutationCtx, dropId: Doc<"drops">["_id"]) {
  await ctx.scheduler.runAfter(0, internal.pipeline.run, { dropId });
}

async function recluster(ctx: MutationCtx, boardId: string) {
  await ctx.scheduler.runAfter(0, internal.clusters.recompute, { boardId });
}

export const submit = mutation({
  args: {
    boardId: v.string(),
    personId: v.string(),
    clientId: v.string(),
    kind: sourceKind,
    text: nullable(v.string()),
    url: nullable(v.string()),
    imageIds: nullable(v.array(v.id("_storage"))),
    capturedAt: v.number(),
    utcOffsetMinutes: nullable(v.number()),
    latitude: nullable(v.number()),
    longitude: nullable(v.number()),
    hints: nullable(hintsArg),
  },
  returns: v.id("drops"),
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("drops")
      .withIndex("by_clientId", (q) => q.eq("clientId", args.clientId))
      .unique();
    if (existing) return existing._id;
    const dropId = await ctx.db.insert("drops", {
      boardId: args.boardId,
      authorId: args.personId,
      clientId: args.clientId,
      kind: args.kind,
      text: args.text ?? undefined,
      url: args.url ?? undefined,
      imageIds: (args.imageIds ?? []).slice(0, 4),
      capturedAt: args.capturedAt,
      utcOffsetMinutes: args.utcOffsetMinutes ?? 0,
      latitude: args.latitude ?? undefined,
      longitude: args.longitude ?? undefined,
      hints: args.hints ? withoutNulls(args.hints) : undefined,
      status: "pending",
      zoneSetByUser: false,
      pinned: false,
      relatedClientIds: [],
      pipeline: freshPipeline(),
      updatedAt: Date.now(),
    });
    await schedule(ctx, dropId);
    return dropId;
  },
});

export const list = query({
  args: { boardId: v.string() },
  returns: v.array(dropView),
  handler: async (ctx, { boardId }) => {
    const drops = await ctx.db
      .query("drops")
      .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
      .order("desc")
      .take(300);
    const members = await membersOf(ctx, boardId);
    const colors = new Map(members.map((m) => [m.personId, m.color]));
    const authorIds = [...new Set([...members.map((m) => m.personId), ...drops.map((d) => d.authorId)])];
    const people = await Promise.all(authorIds.slice(0, 100).map((id) => personById(ctx, id)));
    const names = new Map(people.filter((p) => p !== null).map((p) => [p.personId, p.name]));
    const dropsByClientId = new Map(drops.map((d) => [d.clientId, d]));
    const shown = drops.filter((d) => !d.found?.dismissedAt);
    return await Promise.all(shown.map((d) => toView(ctx, d, dropsByClientId, names, colors)));
  },
});

export const setPinned = mutation({
  args: { boardId: v.string(), clientId: v.string(), pinned: v.boolean() },
  returns: v.null(),
  handler: async (ctx, { boardId, clientId, pinned }) => {
    const drop = await byClientId(ctx, boardId, clientId);
    if (!drop) throw new ConvexError("drop not found on this board");
    if (drop.pinned === pinned) return null;
    await ctx.db.patch("drops", drop._id, {
      pinned,
      pinnedAt: pinned ? Date.now() : undefined,
      updatedAt: Date.now(),
    });
    return null;
  },
});

export const setZone = mutation({
  args: {
    boardId: v.string(),
    clientId: v.string(),
    zone,
  },
  returns: v.null(),
  handler: async (ctx, { boardId, clientId, zone }) => {
    const drop = await byClientId(ctx, boardId, clientId);
    if (!drop) throw new ConvexError("drop not found on this board");
    await ctx.db.patch("drops", drop._id, {
      zone,
      previousZone: drop.zone,
      zoneSetByUser: true,
      updatedAt: Date.now(),
    });
    if (zone === "done" || drop.zone === "done") await recluster(ctx, boardId);
    return null;
  },
});

export const retry = mutation({
  args: { boardId: v.string(), clientId: v.string() },
  returns: v.null(),
  handler: async (ctx, { boardId, clientId }) => {
    const drop = await byClientId(ctx, boardId, clientId);
    if (!drop) throw new ConvexError("drop not found on this board");
    await ctx.db.patch("drops", drop._id, {
      status: "pending",
      pipeline: freshPipeline(),
      updatedAt: Date.now(),
    });
    await schedule(ctx, drop._id);
    return null;
  },
});

export const get = internalQuery({
  args: { dropId: v.id("drops") },
  returns: v.union(dropDoc, v.null()),
  handler: async (ctx, { dropId }) => {
    return await ctx.db.get("drops", dropId);
  },
});

export const searchBoard = internalQuery({
  args: { boardId: v.string(), query: v.string(), excludeClientId: v.string() },
  returns: v.array(dropDoc),
  handler: async (ctx, { boardId, query, excludeClientId }) => {
    if (!query.trim()) return [];
    const hits = await ctx.db
      .query("drops")
      .withSearchIndex("search_text", (q) => q.search("searchText", query).eq("boardId", boardId))
      .take(9);
    return hits.filter((d) => d.clientId !== excludeClientId && d.status === "processed");
  },
});

export const byClientIds = internalQuery({
  args: { boardId: v.string(), clientIds: v.array(v.string()) },
  returns: v.array(dropDoc),
  handler: async (ctx, { boardId, clientIds }) => {
    const drops = await Promise.all(clientIds.slice(0, 10).map((id) => byClientId(ctx, boardId, id)));
    return drops.filter((d): d is Doc<"drops"> => d !== null && d.status === "processed");
  },
});

export const applyResult = internalMutation({
  args: {
    dropId: v.id("drops"),
    enrichment: v.optional(enrichment),
    extraction: v.optional(extraction),
    decision: v.optional(decision),
    suggestion: v.optional(v.string()),
    vibes: v.array(v.string()),
    jevClusterId: v.optional(v.string()),
    relatedClientIds: v.array(v.string()),
    searchText: v.string(),
    pipeline,
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const drop = await ctx.db.get("drops", args.dropId);
    if (!drop) return null;
    const related = [...new Set([...drop.relatedClientIds, ...args.relatedClientIds])];
    await ctx.db.patch("drops", drop._id, {
      status: "processed",
      enrichment: args.enrichment,
      extraction: args.extraction,
      decision: args.decision,
      suggestion: args.suggestion,
      vibes: args.vibes,
      jevClusterId: args.jevClusterId,
      zone: drop.zoneSetByUser ? drop.zone : (args.decision?.zone ?? drop.zone),
      relatedClientIds: related,
      searchText: args.searchText,
      pipeline: args.pipeline,
      updatedAt: Date.now(),
    });
    for (const clientId of args.relatedClientIds) {
      const other = await byClientId(ctx, drop.boardId, clientId);
      if (!other || other.relatedClientIds.includes(drop.clientId)) continue;
      await ctx.db.patch("drops", other._id, {
        relatedClientIds: [...other.relatedClientIds, drop.clientId],
        updatedAt: Date.now(),
      });
    }
    await recluster(ctx, drop.boardId);
    return null;
  },
});

export const markFailed = internalMutation({
  args: { dropId: v.id("drops"), pipeline },
  returns: v.null(),
  handler: async (ctx, { dropId, pipeline }) => {
    const drop = await ctx.db.get("drops", dropId);
    if (!drop) return null;
    await ctx.db.patch("drops", dropId, { status: "failed", pipeline, updatedAt: Date.now() });
    if (drop.clusterId) await recluster(ctx, drop.boardId);
    return null;
  },
});
