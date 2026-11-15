import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  moments: defineTable({
    text: v.string(),
    author: v.string(),
    createdAt: v.number(),
  }).index("by_createdAt", ["createdAt"]),
});
