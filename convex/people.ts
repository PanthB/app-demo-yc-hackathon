import { v } from "convex/values";
import { mutation } from "./_generated/server";
import { nullable, personView } from "./model";
import { ensurePerson, ensurePersonalBoard } from "./boards";

export const upsert = mutation({
  args: { personId: v.string(), personalBoardId: v.string(), name: nullable(v.string()) },
  returns: personView,
  handler: async (ctx, { personId, personalBoardId, name }) => {
    const person = await ensurePerson(ctx, personId, name);
    return {
      personId,
      name: person.name,
      personalBoardId: await ensurePersonalBoard(ctx, person, personalBoardId),
    };
  },
});
