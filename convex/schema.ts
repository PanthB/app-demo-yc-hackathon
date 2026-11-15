import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { dropFields } from "./model";

export default defineSchema({
  moments: defineTable({
    text: v.string(),
    author: v.string(),
    createdAt: v.number(),
  }).index("by_createdAt", ["createdAt"]),
  people: defineTable({
    personId: v.string(),
    name: v.string(),
    personalBoardId: v.optional(v.string()),
    tokenIdentifier: v.optional(v.string()),
  })
    .index("by_personId", ["personId"])
    .index("by_tokenIdentifier", ["tokenIdentifier"]),
  boards: defineTable({
    boardId: v.string(),
    name: v.string(),
    shared: v.boolean(),
    inviteCode: v.optional(v.string()),
    ownerId: v.string(),
  })
    .index("by_boardId", ["boardId"])
    .index("by_inviteCode", ["inviteCode"]),
  members: defineTable({
    boardId: v.string(),
    personId: v.string(),
    color: v.string(),
  })
    .index("by_boardId", ["boardId"])
    .index("by_personId_and_boardId", ["personId", "boardId"]),
  openaiCalls: defineTable({
    model: v.string(),
    route: v.union(v.literal("reader"), v.literal("decisions"), v.literal("events"), v.literal("suggestions")),
    inputTokens: v.number(),
    cachedTokens: v.number(),
    cacheWriteTokens: v.number(),
    outputTokens: v.number(),
    webSearchCalls: v.optional(v.number()),
    usd: v.number(),
  }),
  openaiTotals: defineTable({
    model: v.string(),
    usd: v.number(),
    calls: v.number(),
  }).index("by_model", ["model"]),
  eventSearches: defineTable({
    boardId: v.string(),
    startedAt: v.number(),
    finishedAt: v.optional(v.number()),
    status: v.union(v.literal("searching"), v.literal("done"), v.literal("failed")),
    added: v.optional(v.number()),
    usd: v.optional(v.number()),
    note: v.optional(v.string()),
  }).index("by_boardId", ["boardId"]),
  suggestionSearches: defineTable({
    boardId: v.string(),
    clusterId: v.string(),
    status: v.union(v.literal("scheduled"), v.literal("searching"), v.literal("done"), v.literal("failed")),
    startedAt: v.number(),
    finishedAt: v.optional(v.number()),
    members: v.array(v.string()),
    added: v.optional(v.number()),
    usd: v.optional(v.number()),
    note: v.optional(v.string()),
  })
    .index("by_boardId", ["boardId"]),
  suggestions: defineTable({
    boardId: v.string(),
    clusterId: v.string(),
    kind: v.union(v.literal("event"), v.literal("song"), v.literal("watch"), v.literal("place")),
    title: v.string(),
    by: v.optional(v.string()),
    place: v.optional(v.string()),
    area: v.optional(v.string()),
    startsAt: v.optional(v.number()),
    utcOffsetMinutes: v.number(),
    price: v.optional(v.number()),
    url: v.string(),
    description: v.optional(v.string()),
    reason: v.string(),
    thumbnailUrl: v.optional(v.string()),
    inspiredBy: v.array(v.string()),
    foundAt: v.number(),
    savedAt: v.optional(v.number()),
    savedClientId: v.optional(v.string()),
    dismissedAt: v.optional(v.number()),
  }).index("by_boardId", ["boardId"]),
  drops: defineTable(dropFields)
    .index("by_clientId", ["clientId"])
    .index("by_boardId", ["boardId"])
    .searchIndex("search_text", { searchField: "searchText", filterFields: ["boardId"] }),
});
