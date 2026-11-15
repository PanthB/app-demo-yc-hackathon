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
    route: v.union(v.literal("reader"), v.literal("decisions"), v.literal("events")),
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
  drops: defineTable(dropFields)
    .index("by_clientId", ["clientId"])
    .index("by_boardId", ["boardId"])
    .searchIndex("search_text", { searchField: "searchText", filterFields: ["boardId"] }),
});
