import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { openaiBudgetUsd } from "./lib/models";

export const openai = internalQuery({
  args: {},
  returns: v.object({
    spentUsd: v.number(),
    budgetUsd: v.number(),
    calls: v.number(),
    byModel: v.array(v.object({ model: v.string(), usd: v.number(), calls: v.number() })),
  }),
  handler: async (ctx) => {
    const rows = await ctx.db.query("openaiTotals").take(50);
    return {
      spentUsd: rows.reduce((sum, r) => sum + r.usd, 0),
      budgetUsd: openaiBudgetUsd(),
      calls: rows.reduce((sum, r) => sum + r.calls, 0),
      byModel: rows.map((r) => ({ model: r.model, usd: r.usd, calls: r.calls })),
    };
  },
});

export const recordOpenAI = internalMutation({
  args: {
    model: v.string(),
    route: v.union(v.literal("reader"), v.literal("decisions")),
    inputTokens: v.number(),
    cachedTokens: v.number(),
    cacheWriteTokens: v.number(),
    outputTokens: v.number(),
    usd: v.number(),
  },
  returns: v.null(),
  handler: async (ctx, call) => {
    await ctx.db.insert("openaiCalls", call);
    const total = await ctx.db
      .query("openaiTotals")
      .withIndex("by_model", (q) => q.eq("model", call.model))
      .unique();
    if (total) await ctx.db.patch("openaiTotals", total._id, { usd: total.usd + call.usd, calls: total.calls + 1 });
    else await ctx.db.insert("openaiTotals", { model: call.model, usd: call.usd, calls: 1 });
    return null;
  },
});
