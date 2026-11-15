import { v } from "convex/values";
import { action, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { mode, nullable, type Mode } from "./model";
import { choice, decide, hasOpenAI } from "./lib/models";

const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
const NEAR_MINUTES = 20;

export const upcoming = internalQuery({
  args: { boardId: v.string() },
  returns: v.array(v.object({ clientId: v.string(), title: v.optional(v.string()), zone: v.string() })),
  handler: async (ctx, { boardId }) => {
    const drops = await ctx.db
      .query("drops")
      .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
      .order("desc")
      .take(150);
    return drops
      .filter((d) => d.zone === "tonight" || d.zone === "thisWeekend")
      .map((d) => ({ clientId: d.clientId, title: d.extraction?.title ?? d.enrichment?.title, zone: d.zone as string }));
  },
});

export const decideMode = action({
  args: {
    boardId: v.string(),
    context: v.object({
      latitude: nullable(v.number()),
      longitude: nullable(v.number()),
      localHour: v.number(),
      weekday: v.number(),
      atHome: v.boolean(),
      nearby: nullable(v.array(v.object({ clientId: v.string(), minutesAway: v.number() }))),
    }),
  },
  returns: v.object({
    mode,
    probabilities: v.record(v.string(), v.number()),
    bringForward: v.array(v.string()),
    decidedBy: v.string(),
    reason: v.optional(v.string()),
  }),
  handler: async (ctx, { boardId, context }) => {
    const nearby = [...(context.nearby ?? [])].sort((a, b) => a.minutesAway - b.minutesAway);
    const close = nearby.filter((n) => n.minutesAway <= NEAR_MINUTES);
    const upcoming: { clientId: string; title?: string; zone: string }[] = await ctx.runQuery(internal.board.upcoming, { boardId });
    const bringForwardFor = (m: Mode) =>
      m === "wandering" ? close.slice(0, 5).map((n) => n.clientId) : upcoming.slice(0, 5).map((u) => u.clientId);
    const ruled: Mode = !context.atHome && close.length > 0 ? "wandering" : "planning";
    const ruledResult = (decidedBy: string, reason?: string) => ({
      mode: ruled,
      probabilities: { planning: ruled === "planning" ? 0.7 : 0.3, wandering: ruled === "wandering" ? 0.7 : 0.3 },
      bringForward: bringForwardFor(ruled),
      decidedBy,
      reason,
    });
    if (!hasOpenAI()) return ruledResult("rules", "no OPENAI_API_KEY in the convex env");
    try {
      const { answers, by } = await decide(
        ctx,
        {
          local_time: `${WEEKDAYS[context.weekday - 1] ?? "unknown day"}, ${context.localHour}:00`,
          at_home: context.atHome,
          saved_things_nearby: nearby.slice(0, 10).map((n) => `${n.minutesAway} min away`),
          coming_up: upcoming.slice(0, 10).map((u) => `${u.title ?? "untitled"} (${u.zone})`),
        },
        {
          mode: {
            type: "choice",
            instructions: "Which board mode fits the person's situation right now?",
            criteria: {
              planning: "they are at home or settled, so show what is coming up tonight and this weekend",
              wandering: "they are out and some saved things are a short walk away, so point toward those",
            },
          },
        },
      );
      const picked = choice(answers.mode);
      if (!picked) return ruledResult("rules", "the decider returned no mode");
      const chosen = picked.choice as Mode;
      return { mode: chosen, probabilities: picked.probabilities ?? {}, bringForward: bringForwardFor(chosen), decidedBy: by };
    } catch (e) {
      return ruledResult("rules", `decider failed: ${(e instanceof Error ? e.message : String(e)).slice(0, 200)}`);
    }
  },
});
