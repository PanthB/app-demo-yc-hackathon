import { ConvexError, v } from "convex/values";
import { internalQuery, mutation, query, type MutationCtx, type QueryCtx } from "./_generated/server";
import type { Doc } from "./_generated/dataModel";
import { boardView, nullable, PALETTE } from "./model";

const CODE_LETTERS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

const cleanName = (name: string | null | undefined, max: number) => {
  const clean = name?.trim().toLowerCase().slice(0, max);
  return clean || undefined;
};

export const normalizeCode = (code: string) => code.toUpperCase().replace(/[^A-Z0-9]/g, "");

export async function personById(ctx: QueryCtx, personId: string) {
  return await ctx.db
    .query("people")
    .withIndex("by_personId", (q) => q.eq("personId", personId))
    .unique();
}

export async function boardById(ctx: QueryCtx, boardId: string) {
  return await ctx.db
    .query("boards")
    .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
    .unique();
}

export async function membersOf(ctx: QueryCtx, boardId: string) {
  return await ctx.db
    .query("members")
    .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
    .take(64);
}

async function membership(ctx: QueryCtx, personId: string, boardId: string) {
  return await ctx.db
    .query("members")
    .withIndex("by_personId_and_boardId", (q) => q.eq("personId", personId).eq("boardId", boardId))
    .unique();
}

export async function ensurePerson(ctx: MutationCtx, personId: string, name?: string | null) {
  const clean = cleanName(name, 24);
  const person = await personById(ctx, personId);
  if (!person) {
    const id = await ctx.db.insert("people", { personId, name: clean ?? "me" });
    return (await ctx.db.get("people", id))!;
  }
  if (clean && clean !== person.name) await ctx.db.patch("people", person._id, { name: clean });
  return { ...person, name: clean ?? person.name };
}

export async function addMember(ctx: MutationCtx, boardId: string, personId: string) {
  const existing = await membership(ctx, personId, boardId);
  if (existing) return;
  const members = await membersOf(ctx, boardId);
  const used = new Set(members.map((m) => m.color));
  const color = PALETTE.find((c) => !used.has(c)) ?? PALETTE[members.length % PALETTE.length];
  await ctx.db.insert("members", { boardId, personId, color });
}

async function newInviteCode(ctx: QueryCtx) {
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = Array.from({ length: 6 }, () => CODE_LETTERS[Math.floor(Math.random() * CODE_LETTERS.length)]).join("");
    const taken = await ctx.db
      .query("boards")
      .withIndex("by_inviteCode", (q) => q.eq("inviteCode", code))
      .first();
    if (!taken) return code;
  }
  throw new ConvexError("couldn't make an invite code, try again.");
}

export async function toBoardView(ctx: QueryCtx, board: Doc<"boards">) {
  const members = await membersOf(ctx, board.boardId);
  const people = await Promise.all(members.map((m) => personById(ctx, m.personId)));
  return {
    boardId: board.boardId,
    name: board.name,
    shared: board.shared,
    inviteCode: board.inviteCode,
    ownerId: board.ownerId,
    members: members.map((m, i) => ({
      personId: m.personId,
      name: people[i]?.name ?? "me",
      color: m.color,
      joinedAt: m._creationTime,
    })),
    createdAt: board._creationTime,
  };
}

export async function ensurePersonalBoard(ctx: MutationCtx, person: Doc<"people">, boardId: string) {
  if (person.personalBoardId) return person.personalBoardId;
  const board = await boardById(ctx, boardId);
  if (board && board.ownerId !== person.personId) throw new ConvexError("that board id is already taken.");
  if (!board) await ctx.db.insert("boards", { boardId, name: "my board", shared: false, ownerId: person.personId });
  await addMember(ctx, boardId, person.personId);
  await ctx.db.patch("people", person._id, { personalBoardId: boardId });
  return boardId;
}

export const create = mutation({
  args: { personId: v.string(), boardId: v.string(), name: v.string(), personName: nullable(v.string()) },
  returns: boardView,
  handler: async (ctx, { personId, boardId, name, personName }) => {
    await ensurePerson(ctx, personId, personName);
    const existing = await boardById(ctx, boardId);
    if (existing) {
      if (!(await membership(ctx, personId, boardId))) throw new ConvexError("that board id is already taken.");
      return await toBoardView(ctx, existing);
    }
    const id = await ctx.db.insert("boards", {
      boardId,
      name: cleanName(name, 40) ?? "our board",
      shared: true,
      inviteCode: await newInviteCode(ctx),
      ownerId: personId,
    });
    await addMember(ctx, boardId, personId);
    return await toBoardView(ctx, (await ctx.db.get("boards", id))!);
  },
});

export const join = mutation({
  args: { personId: v.string(), code: v.string(), personName: nullable(v.string()) },
  returns: boardView,
  handler: async (ctx, { personId, code, personName }) => {
    const normalized = normalizeCode(code);
    const board = normalized
      ? await ctx.db
          .query("boards")
          .withIndex("by_inviteCode", (q) => q.eq("inviteCode", normalized))
          .unique()
      : null;
    if (!board) throw new ConvexError("there's no board with that code.");
    await ensurePerson(ctx, personId, personName);
    await addMember(ctx, board.boardId, personId);
    return await toBoardView(ctx, board);
  },
});

export const leave = mutation({
  args: { boardId: v.string(), personId: v.string() },
  returns: v.null(),
  handler: async (ctx, { boardId, personId }) => {
    const board = await boardById(ctx, boardId);
    if (!board) throw new ConvexError("there's no board with that id.");
    if (!board.shared) throw new ConvexError("you can't leave your own board.");
    const member = await membership(ctx, personId, boardId);
    if (member) await ctx.db.delete("members", member._id);
    return null;
  },
});

export const mine = query({
  args: { personId: v.string() },
  returns: v.array(boardView),
  handler: async (ctx, { personId }) => {
    const memberships = await ctx.db
      .query("members")
      .withIndex("by_personId_and_boardId", (q) => q.eq("personId", personId))
      .take(50);
    const boards = (await Promise.all(memberships.map((m) => boardById(ctx, m.boardId))))
      .map((board, i) => ({ board, joinedAt: memberships[i]._creationTime }))
      .filter((x): x is { board: Doc<"boards">; joinedAt: number } => x.board !== null)
      .sort((a, b) => Number(a.board.shared) - Number(b.board.shared) || a.joinedAt - b.joinedAt);
    return await Promise.all(boards.map((x) => toBoardView(ctx, x.board)));
  },
});

export const names = internalQuery({
  args: { personIds: v.array(v.string()) },
  returns: v.record(v.string(), v.string()),
  handler: async (ctx, { personIds }) => {
    const unique = [...new Set(personIds)].slice(0, 20);
    const people = await Promise.all(unique.map((id) => personById(ctx, id)));
    return Object.fromEntries(people.filter((p) => p !== null).map((p) => [p.personId, p.name]));
  },
});
