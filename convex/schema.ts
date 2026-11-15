import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { dropFields } from "./model";

export default defineSchema({
  moments: defineTable({
    text: v.string(),
    author: v.string(),
    createdAt: v.number(),
  }).index("by_createdAt", ["createdAt"]),
  drops: defineTable(dropFields)
    .index("by_clientId", ["clientId"])
    .index("by_boardId", ["boardId"])
    .searchIndex("search_text", { searchField: "searchText", filterFields: ["boardId"] }),
});
