import { ConvexError, v, type Infer } from "convex/values";
import { internalAction, internalMutation, type MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { enrichment, PALETTE, type DropType, type Enrichment, type ObjectKind, type SourceKind, type Stage, type Zone } from "./model";
import { boardById, ensurePerson, membersOf } from "./boards";
import { enrichLink } from "./lib/enrich";
import { DROP_TYPES, ruleExtraction, spread, TIME_ZONES, whenLabelFor } from "./lib/rules";

const CREW_BOARD = "sf-crew";
const INVITE_CODE = "SFCREW";
const MY_BOARD = "seed-panth-board";
const OFFSET = -480;
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const PEOPLE = ["panth", "maya", "sam", "alex"] as const;
type Person = (typeof PEOPLE)[number];

const seedClientId = (board: 1 | 2, n: number) => `5EED000${board}-0000-4000-8000-${n.toString(16).toUpperCase().padStart(12, "0")}`;
const personId = (name: Person) => `seed-${name}`;

const boardResult = v.object({ created: v.number(), reset: v.number(), images: v.number(), removedDrops: v.number(), removedMembers: v.number() });

type SeedDrop = {
  n: number;
  author?: Person;
  kind: SourceKind;
  minutesAgo: number;
  type: DropType;
  objectKind: ObjectKind;
  zone: Zone;
  title?: string;
  text?: string;
  url?: string;
  image?: string;
  place?: string;
  latitude?: number;
  longitude?: number;
  artist?: string;
  transcript?: string;
  price?: number;
  startsAt?: number;
  dueAt?: number;
  whenLabel?: string;
  pinnedHoursAgo?: number;
  unsure?: boolean;
  doneFrom?: Zone;
  vibes?: string[];
  clusterId?: string;
};

const clip = (s: Omit<SeedDrop, "kind" | "type" | "objectKind" | "zone">): SeedDrop => ({ ...s, kind: "url", type: "mood", objectKind: "polaroid", zone: "vibes" });
const song = (s: Omit<SeedDrop, "kind" | "type" | "objectKind" | "zone">): SeedDrop => ({ ...s, kind: "url", type: "song", objectKind: "record", zone: "vibes" });
const place = (s: Omit<SeedDrop, "kind" | "type" | "objectKind" | "zone">): SeedDrop => ({ ...s, kind: "url", type: "place", objectKind: "postcard", zone: "someday" });

const SUNNY = "sunny-afternoons";
const LATE = "late-night";
const GOLDEN = "golden-hour";

const CREW: SeedDrop[] = [
  clip({ n: 1, author: "maya", minutesAgo: 300, image: "seed-dolores-sunny", title: "dolores park on a sunny day", url: "https://www.tiktok.com/@graacciiee/video/7617551860244745503", place: "dolores park", latitude: 37.75972, longitude: -122.42713, pinnedHoursAgo: 2, vibes: ["sunny outdoors", "upbeat", "outdoors", "mission"], clusterId: SUNNY }),
  place({ n: 2, author: "sam", minutesAgo: 1500, title: "la palma mexicatessen", url: "https://www.lapalmasf.com/", place: "la palma mexicatessen", latitude: 37.75268, longitude: -122.41128, vibes: ["food & drinks", "cozy", "morning", "food", "mission"], clusterId: SUNNY }),
  place({ n: 3, author: "alex", minutesAgo: 2600, image: "seed-matcha", title: "stonemill matcha", url: "https://www.stonemillmatcha-us.com/", place: "stonemill matcha", latitude: 37.76402, longitude: -122.42153, vibes: ["food & drinks", "calm", "morning", "mission"], clusterId: SUNNY }),
  song({ n: 4, author: "panth", minutesAgo: 900, image: "seed-flowers", title: "san francisco (be sure to wear flowers in your hair)", artist: "scott mckenzie", url: "https://open.spotify.com/track/6UsdldEfcEXSID2G3nA89J", vibes: ["sunny songs", "upbeat", "folk", "steady"], clusterId: SUNNY }),
  clip({ n: 5, author: "maya", minutesAgo: 4000, image: "seed-15things", title: "15 things to do in sf", url: "https://www.tiktok.com/@marissadaily_/video/7541446036347309343", vibes: ["sunny outdoors", "upbeat", "outdoors"], clusterId: SUNNY }),
  clip({ n: 6, author: "alex", minutesAgo: 700, image: "seed-foodtour", title: "mission district food tour", url: "https://www.tiktok.com/@thesnacksensei/video/7561602082596343095", vibes: ["food & drinks", "late night", "food", "mission"], clusterId: LATE }),
  place({ n: 7, author: "sam", minutesAgo: 2000, title: "taqueria vallarta", url: "https://theyard4540.com/", place: "taqueria vallarta", latitude: 37.7526, longitude: -122.4134, vibes: ["food & drinks", "cozy", "late night", "food"], clusterId: LATE }),
  song({ n: 8, author: "panth", minutesAgo: 3100, image: "seed-dreams", title: "dreams", artist: "fleetwood mac", url: "https://open.spotify.com/track/0ofHAoxe9vBkTCp2UQIavz", vibes: ["sad songs", "dreamy", "late night", "rock", "steady"], clusterId: LATE }),
  song({ n: 9, author: "maya", minutesAgo: 1200, image: "seed-nights", title: "nights like this", artist: "kehlani", url: "https://open.spotify.com/track/6ZRuF2n1CQxyxxAAWsKJOy", vibes: ["sad songs", "moody", "late night", "r&b", "slow"], clusterId: LATE }),
  place({ n: 10, author: "alex", minutesAgo: 5200, image: "seed-concert", title: "the chapel", url: "https://thechapelsf.com", place: "the chapel", latitude: 37.76049, longitude: -122.4212, vibes: ["food & drinks", "late night", "live music", "mission"], clusterId: LATE }),
  clip({ n: 11, author: "panth", minutesAgo: 450, image: "seed-fortpoint", title: "golden gate from fort point", url: "https://www.instagram.com/p/DWCN6pbgn3F/", place: "fort point", latitude: 37.8106, longitude: -122.4771, vibes: ["sunny outdoors", "golden hour", "by the water", "calm", "presidio"], clusterId: GOLDEN }),
  clip({ n: 12, author: "sam", minutesAgo: 3600, image: "seed-ggreel", title: "the golden gate still feels unreal", url: "https://www.instagram.com/reel/DbySW82ILGn/", vibes: ["sunny outdoors", "golden hour", "by the water", "dreamy"], clusterId: GOLDEN }),
  song({ n: 13, author: "maya", minutesAgo: 6100, title: "a little lost", artist: "arthur russell", url: "https://open.spotify.com/track/1ToKOSrvlMVSPvFyvU9FvX", vibes: ["sad songs", "calm", "golden hour", "slow"], clusterId: GOLDEN }),
  song({ n: 14, author: "alex", minutesAgo: 2300, image: "seed-pinkwhite", title: "pink + white", artist: "frank ocean", url: "https://open.spotify.com/track/3xKsf9qdS1CyvXSMEid6g8", vibes: ["sunny songs", "dreamy", "golden hour", "r&b", "steady"], clusterId: GOLDEN }),
  place({ n: 15, author: "panth", minutesAgo: 8000, image: "seed-landsend", title: "lands end trail", url: "https://www.nps.gov/goga/planyourvisit/landsend.htm", place: "lands end", latitude: 37.7802, longitude: -122.5115, pinnedHoursAgo: 20, vibes: ["sunny outdoors", "golden hour", "by the water", "outdoors", "lands end"], clusterId: GOLDEN }),
];

const CREW_PAIRS: [number, number][] = [
  [1, 2],
  [6, 7],
];

function myDrops(now: number): SeedDrop[] {
  const local = (t: number) => new Date(t + OFFSET * MINUTE);
  const today = Date.UTC(local(now).getUTCFullYear(), local(now).getUTCMonth(), local(now).getUTCDate()) - OFFSET * MINUTE;
  const saturday = today + ((6 - local(now).getUTCDay() + 7) % 7) * DAY;
  const sunday = saturday + DAY;
  const roundUp = (t: number, minutes: number) => Math.ceil(t / (minutes * MINUTE)) * minutes * MINUTE;
  return [
    { n: 1, kind: "text", minutesAgo: 2, type: "note", objectKind: "sticky", zone: "now", text: "remind me in 1 hr to call mom back", dueAt: now + 58 * MINUTE, whenLabel: "in 1 hr" },
    { n: 2, kind: "image", minutesAgo: 600, type: "place", objectKind: "cutout", zone: "tonight", title: "tonkotsu ramen", image: "seed-ramen", place: "mensho tokyo", latitude: 37.7869, longitude: -122.4137, startsAt: Math.max(today + 19.5 * HOUR, roundUp(now + 2 * HOUR, 30)) },
    { n: 3, kind: "url", minutesAgo: 200, type: "event", objectKind: "postcard", zone: "tonight", title: "late show at the strand", url: "https://www.act-sf.org/the-strand", image: "seed-strand", place: "the strand theater", latitude: 37.7787, longitude: -122.4139, startsAt: Math.max(today + 21.75 * HOUR, roundUp(now + 3 * HOUR, 15)) },
    { n: 4, kind: "url", minutesAgo: 1440, type: "event", objectKind: "stub", zone: "thisWeekend", title: "poi dog pondering at the chapel", url: "https://goseeshows.com/san-francisco/shows/2026-11-21-the-chapel-poi-dog-pondering/", place: "the chapel", price: 28, startsAt: saturday + 20 * HOUR },
    { n: 5, kind: "audio", minutesAgo: 300, type: "note", objectKind: "slip", zone: "thisWeekend", transcript: "the thrift spots on valencia, the one with the green awning first", startsAt: saturday + 11 * HOUR },
    { n: 6, kind: "text", minutesAgo: 2880, type: "event", objectKind: "sticky", zone: "thisWeekend", title: "sam's birthday dinner", text: "sam's birthday dinner at nopa saturday 7pm", place: "nopa", latitude: 37.7748, longitude: -122.4376, startsAt: saturday + 19 * HOUR, whenLabel: "saturday at 7pm", pinnedHoursAgo: 26 },
    { n: 7, kind: "image", minutesAgo: 420, type: "event", objectKind: "polaroid", zone: "thisWeekend", title: "picnic at dolores", text: "picnic at dolores sunday, bring a blanket", image: "seed-dolores", place: "dolores park", latitude: 37.7596, longitude: -122.4269, startsAt: sunday + 13 * HOUR, pinnedHoursAgo: 3 },
    { n: 8, kind: "url", minutesAgo: 9000, type: "place", objectKind: "postcard", zone: "someday", title: "muir woods", url: "https://www.nps.gov/muwo/planyourvisit/index.htm", place: "muir woods", latitude: 37.897, longitude: -122.5811 },
    { n: 9, kind: "text", minutesAgo: 7000, type: "note", objectKind: "sticky", zone: "someday", text: "that pottery class maya mentioned", unsure: true },
    { n: 10, kind: "url", minutesAgo: 6000, type: "event", objectKind: "stub", zone: "someday", title: "beach bunny at the fillmore", url: "https://goseeshows.com/san-francisco/shows/2027-03-13-the-fillmore-beach-bunny/", place: "the fillmore", startsAt: Date.UTC(2027, 2, 13, 20) - OFFSET * MINUTE, whenLabel: "sometime in march" },
    { n: 11, kind: "url", minutesAgo: 6500, type: "note", objectKind: "postcard", zone: "someday", title: "the best burritos in the mission", url: "https://sf.eater.com/maps/best-burritos-san-francisco" },
    { n: 12, kind: "url", minutesAgo: 3000, type: "song", objectKind: "record", zone: "vibes", title: "lights", url: "https://open.spotify.com/track/7EHmKkyAr6MZv5Y2FdZbXw", artist: "journey" },
    { n: 13, kind: "image", minutesAgo: 5000, type: "mood", objectKind: "polaroid", zone: "vibes", text: "soft pink everything", image: "seed-pinksky" },
    { n: 14, kind: "url", minutesAgo: 20000, type: "place", objectKind: "postcard", zone: "done", title: "the dumpling place", place: "dumpling home", doneFrom: "someday" },
  ];
}

async function ensureBoard(ctx: MutationCtx, boardId: string, fields: { name: string; shared: boolean; inviteCode?: string }) {
  if (await boardById(ctx, boardId)) return;
  if (fields.inviteCode) {
    const code = fields.inviteCode;
    const taken = await ctx.db
      .query("boards")
      .withIndex("by_inviteCode", (q) => q.eq("inviteCode", code))
      .first();
    if (taken) throw new ConvexError(`invite code ${code} already belongs to ${taken.boardId}`);
  }
  await ctx.db.insert("boards", { boardId, ownerId: personId("panth"), ...fields });
}

async function setMembers(ctx: MutationCtx, boardId: string, people: readonly Person[]) {
  const wanted = people.map(personId);
  const members = await membersOf(ctx, boardId);
  let removed = 0;
  for (const m of members) {
    if (wanted.includes(m.personId)) continue;
    await ctx.db.delete("members", m._id);
    removed++;
  }
  for (const [i, id] of wanted.entries()) {
    const m = members.find((x) => x.personId === id);
    if (!m) await ctx.db.insert("members", { boardId, personId: id, color: PALETTE[i] });
    else if (m.color !== PALETTE[i]) await ctx.db.patch("members", m._id, { color: PALETTE[i] });
  }
  return removed;
}

async function clearEventSearches(ctx: MutationCtx, boardId: string) {
  const searches = await ctx.db
    .query("eventSearches")
    .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
    .take(200);
  for (const s of searches) await ctx.db.delete("eventSearches", s._id);
}

async function clearSuggestions(ctx: MutationCtx, boardId: string) {
  const suggestions = await ctx.db
    .query("suggestions")
    .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
    .take(300);
  for (const s of suggestions) await ctx.db.delete("suggestions", s._id);
  const searches = await ctx.db
    .query("suggestionSearches")
    .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
    .take(300);
  for (const s of searches) await ctx.db.delete("suggestionSearches", s._id);
}

async function removeOtherDrops(ctx: MutationCtx, boardId: string, keep: string[]) {
  const drops = await ctx.db
    .query("drops")
    .withIndex("by_boardId", (q) => q.eq("boardId", boardId))
    .take(300);
  let removed = 0;
  for (const d of drops) {
    if (keep.includes(d.clientId)) continue;
    for (const id of d.imageIds) await ctx.storage.delete(id);
    await ctx.db.delete("drops", d._id);
    removed++;
  }
  return removed;
}

async function seededDrop(ctx: MutationCtx, boardId: string, clientId: string) {
  const existing = await ctx.db
    .query("drops")
    .withIndex("by_clientId", (q) => q.eq("clientId", clientId))
    .unique();
  if (existing && existing.boardId !== boardId) throw new ConvexError(`${clientId} is already on board ${existing.boardId}`);
  return existing;
}

async function writeSeeds(
  ctx: MutationCtx,
  board: { id: string; prefix: 1 | 2; pairs: [number, number][] },
  seeds: SeedDrop[],
  images: Record<string, Id<"_storage">>,
  enrichments: Record<string, Enrichment>,
) {
  const now = Date.now();
  const used = new Set<Id<"_storage">>();
  let created = 0;
  let reset = 0;
  for (const s of seeds) {
    const clientId = seedClientId(board.prefix, s.n);
    const capturedAt = now - s.minutesAgo * MINUTE;
    const imageIds = s.image && images[s.image] ? [images[s.image]] : [];
    imageIds.forEach((id) => used.add(id));
    const hints = s.transcript || s.artist || s.place ? { transcript: s.transcript, artist: s.artist, placeName: s.place } : undefined;
    const words = ruleExtraction({ text: [s.title, s.text, s.transcript].filter(Boolean).join("\n"), url: s.url, capturedAt, utcOffsetMinutes: OFFSET });
    const anchor = s.dueAt ?? s.startsAt;
    const whenLabel = s.whenLabel ?? (anchor ? whenLabelFor(anchor, now, OFFSET) : undefined);
    const pickedZone = s.doneFrom ?? s.zone;
    const stage: Stage = { ran: "skipped", reason: "seeded for the demo" };
    const linked: Enrichment | undefined = enrichments[clientId];
    const related = board.pairs.flatMap(([a, b]) => (a === s.n ? [b] : b === s.n ? [a] : [])).map((n) => seedClientId(board.prefix, n));
    const searchText = [
      s.title && `title: ${s.title}`,
      s.place && `place: ${s.place}`,
      whenLabel && `when: ${whenLabel}`,
      words.kindWords.length > 0 && `kind: ${words.kindWords.join(", ")}`,
      s.vibes && s.vibes.length > 0 && `vibe: ${s.vibes.join(", ")}`,
      s.text && `note: ${s.text}`,
      s.artist && `by: ${s.artist}`,
      s.transcript && `voice note: ${s.transcript}`,
      s.url && `link: ${s.url}`,
    ]
      .filter(Boolean)
      .join("\n");
    const drop = {
      boardId: board.id,
      authorId: personId(s.author ?? "panth"),
      clientId,
      kind: s.kind,
      text: s.text,
      url: s.url,
      imageIds,
      capturedAt,
      utcOffsetMinutes: OFFSET,
      latitude: s.latitude,
      longitude: s.longitude,
      hints,
      status: "processed" as const,
      enrichment: s.url ? { ...linked, provider: linked?.provider ?? "seed", title: s.title, author: s.artist ?? linked?.author } : undefined,
      extraction: {
        title: s.title,
        placeName: s.place,
        startsAt: s.startsAt,
        dueAt: s.dueAt,
        whenLabel,
        price: s.price,
        kindWords: words.kindWords,
        vibeWords: words.vibeWords,
        confidence: s.unsure ? 0.3 : 0.9,
      },
      decision: {
        type: s.type,
        zone: pickedZone,
        objectKind: s.objectKind,
        emphasis: "normal" as const,
        unsure: Boolean(s.unsure),
        typeProbabilities: spread(DROP_TYPES, s.type, 0.8),
        zoneProbabilities: spread(TIME_ZONES, pickedZone, s.unsure ? 0.4 : 0.8),
      },
      zone: s.zone,
      zoneSetByUser: Boolean(s.doneFrom),
      previousZone: s.doneFrom,
      pinned: s.pinnedHoursAgo !== undefined,
      pinnedAt: s.pinnedHoursAgo === undefined ? undefined : now - s.pinnedHoursAgo * HOUR,
      vibes: s.vibes,
      clusterId: s.clusterId,
      relatedClientIds: related,
      pipeline: { enrich: stage, extract: stage, remember: stage, decide: stage, connect: stage, startedAt: capturedAt, finishedAt: capturedAt },
      searchText,
      updatedAt: now,
    };
    const existing = await seededDrop(ctx, board.id, clientId);
    if (!existing) {
      await ctx.db.insert("drops", drop);
      created++;
      continue;
    }
    for (const old of existing.imageIds) if (!imageIds.includes(old)) await ctx.storage.delete(old);
    await ctx.db.replace("drops", existing._id, drop);
    reset++;
  }
  await ctx.scheduler.runAfter(0, internal.clusters.recompute, { boardId: board.id });
  return { created, reset, used };
}

export const sfCrew = internalMutation({
  args: { images: v.record(v.string(), v.id("_storage")), enrichments: v.record(v.string(), enrichment) },
  returns: boardResult,
  handler: async (ctx, { images, enrichments }) => {
    for (const name of PEOPLE) await ensurePerson(ctx, personId(name), name);
    await ensureBoard(ctx, CREW_BOARD, { name: "sf crew", shared: true, inviteCode: INVITE_CODE });
    const removedMembers = await setMembers(ctx, CREW_BOARD, PEOPLE);
    const removedDrops = await removeOtherDrops(ctx, CREW_BOARD, CREW.map((s) => seedClientId(2, s.n)));
    await clearSuggestions(ctx, CREW_BOARD);
    await clearEventSearches(ctx, CREW_BOARD);
    const { created, reset, used } = await writeSeeds(ctx, { id: CREW_BOARD, prefix: 2, pairs: CREW_PAIRS }, CREW, images, enrichments);
    return { created, reset, images: used.size, removedDrops, removedMembers };
  },
});

export const myBoard = internalMutation({
  args: { images: v.record(v.string(), v.id("_storage")), enrichments: v.record(v.string(), enrichment) },
  returns: boardResult,
  handler: async (ctx, { images, enrichments }) => {
    const panth = await ensurePerson(ctx, personId("panth"), "panth");
    await ensureBoard(ctx, MY_BOARD, { name: "my board", shared: false });
    if (panth.personalBoardId !== MY_BOARD) await ctx.db.patch("people", panth._id, { personalBoardId: MY_BOARD });
    const removedMembers = await setMembers(ctx, MY_BOARD, ["panth"]);
    const seeds = myDrops(Date.now());
    const removedDrops = await removeOtherDrops(ctx, MY_BOARD, seeds.map((s) => seedClientId(1, s.n)));
    await clearSuggestions(ctx, MY_BOARD);
    await clearEventSearches(ctx, MY_BOARD);
    const { created, reset, used } = await writeSeeds(ctx, { id: MY_BOARD, prefix: 1, pairs: [] }, seeds, images, enrichments);
    return { created, reset, images: used.size, removedDrops, removedMembers };
  },
});

export const run = internalAction({
  args: { images: v.optional(v.record(v.string(), v.id("_storage"))) },
  returns: v.object({ myBoard: boardResult, sfCrew: boardResult, linkFetchFailures: v.array(v.string()) }),
  handler: async (ctx, { images = {} }) => {
    const wanted = new Set([...myDrops(Date.now()), ...CREW].map((s) => s.image));
    for (const [name, id] of Object.entries(images)) if (!wanted.has(name)) await ctx.storage.delete(id);
    const enrichments: Record<string, Enrichment> = {};
    const linkFetchFailures: string[] = [];
    const links = [
      ...myDrops(Date.now()).map((s) => ({ clientId: seedClientId(1, s.n), url: s.url })),
      ...CREW.map((s) => ({ clientId: seedClientId(2, s.n), url: s.url })),
    ];
    for (const { clientId, url } of links) {
      if (!url) continue;
      try {
        enrichments[clientId] = await enrichLink(url);
      } catch (e) {
        linkFetchFailures.push(`${url}: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
    const myBoard: Infer<typeof boardResult> = await ctx.runMutation(internal.seed.myBoard, { images, enrichments });
    const sfCrew: Infer<typeof boardResult> = await ctx.runMutation(internal.seed.sfCrew, { images, enrichments });
    return { myBoard, sfCrew, linkFetchFailures };
  },
});
