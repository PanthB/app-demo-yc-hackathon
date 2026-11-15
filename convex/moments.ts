import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

const moment = v.object({
  _id: v.id("moments"),
  _creationTime: v.number(),
  text: v.string(),
  author: v.string(),
  createdAt: v.number(),
});

export const list = query({
  args: {},
  returns: v.array(moment),
  handler: async (ctx) => {
    return await ctx.db
      .query("moments")
      .withIndex("by_createdAt")
      .order("desc")
      .take(100);
  },
});

export const add = mutation({
  args: { text: v.string(), author: v.string() },
  returns: v.id("moments"),
  handler: async (ctx, { text, author }) => {
    return await ctx.db.insert("moments", {
      text,
      author,
      createdAt: Date.now(),
    });
  },
});
