import { ConvexError, v } from "convex/values";
import { mutation } from "./_generated/server";
import type { Doc } from "./_generated/dataModel";
import { nullable, personView } from "./model";
import { ensurePerson, ensurePersonalBoard, personById } from "./boards";

const prefs = (p: Doc<"people">) => ({ recsMedia: p.recsMedia ?? true, recsEvents: p.recsEvents ?? true });

export const upsert = mutation({
  args: { personId: v.string(), personalBoardId: v.string(), name: nullable(v.string()) },
  returns: personView,
  handler: async (ctx, { personId, personalBoardId, name }) => {
    const person = await ensurePerson(ctx, personId, name);
    return {
      personId,
      name: person.name,
      personalBoardId: await ensurePersonalBoard(ctx, person, personalBoardId),
      ...prefs(person),
    };
  },
});

export const link = mutation({
  args: { personId: v.string(), personalBoardId: v.string(), name: nullable(v.string()) },
  returns: personView,
  handler: async (ctx, { personId, personalBoardId, name }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("sign in with apple first.");
    const tokenName = identity.name ?? identity.givenName;
    const linked = await ctx.db
      .query("people")
      .withIndex("by_tokenIdentifier", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .unique();
    if (linked && linked.personId !== personId) {
      const person = await ensurePerson(ctx, linked.personId, tokenName);
      return { personId: person.personId, name: person.name, personalBoardId: await ensurePersonalBoard(ctx, person, personalBoardId), ...prefs(person) };
    }
    const existing = await personById(ctx, personId);
    if (existing?.tokenIdentifier && existing.tokenIdentifier !== identity.tokenIdentifier) {
      throw new ConvexError("this person is already linked to another account.");
    }
    const person = await ensurePerson(ctx, personId, tokenName ?? name);
    if (!person.tokenIdentifier) await ctx.db.patch("people", person._id, { tokenIdentifier: identity.tokenIdentifier });
    return { personId, name: person.name, personalBoardId: await ensurePersonalBoard(ctx, person, personalBoardId), ...prefs(person) };
  },
});

export const setPrefs = mutation({
  args: { personId: v.string(), recsMedia: nullable(v.boolean()), recsEvents: nullable(v.boolean()) },
  returns: v.object({ recsMedia: v.boolean(), recsEvents: v.boolean() }),
  handler: async (ctx, { personId, recsMedia, recsEvents }) => {
    const person = await personById(ctx, personId);
    if (!person) throw new ConvexError("this person isn't set up yet.");
    const patch = { recsMedia: recsMedia ?? person.recsMedia, recsEvents: recsEvents ?? person.recsEvents };
    await ctx.db.patch("people", person._id, patch);
    return prefs({ ...person, ...patch });
  },
});
