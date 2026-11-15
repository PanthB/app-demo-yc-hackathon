import { ConvexError, v } from "convex/values";
import { internalMutation } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import type { DropType, ObjectKind, SourceKind, Stage, Zone } from "./model";
import { addMember, boardById, ensurePerson } from "./boards";
import { DROP_TYPES, ruleExtraction, spread, TIME_ZONES, whenLabelFor } from "./lib/rules";

const BOARD_ID = "sf-crew";
const INVITE_CODE = "SFCREW";
const OFFSET = -480;
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const PEOPLE = ["panth", "maya", "sam", "alex"] as const;
type Person = (typeof PEOPLE)[number];

const seedClientId = (n: number) => `5EED0000-0000-4000-8000-${n.toString(16).toUpperCase().padStart(12, "0")}`;
const personId = (name: Person) => `seed-${name}`;

type SeedDrop = {
  n: number;
  author: Person;
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
  siteName?: string;
  transcript?: string;
  price?: number;
  startsAt?: number;
  dueAt?: number;
  whenLabel?: string;
  pinnedAt?: number;
  unsure?: boolean;
  doneFrom?: Zone;
};

function seedDrops(now: number): SeedDrop[] {
  const local = (t: number) => new Date(t + OFFSET * MINUTE);
  const today = Date.UTC(local(now).getUTCFullYear(), local(now).getUTCMonth(), local(now).getUTCDate()) - OFFSET * MINUTE;
  const saturday = today + ((6 - local(now).getUTCDay() + 7) % 7) * DAY;
  const sunday = saturday + DAY;
  const roundUp = (t: number, minutes: number) => Math.ceil(t / (minutes * MINUTE)) * minutes * MINUTE;
  return [
    { n: 1, author: "panth", kind: "text", minutesAgo: 2, type: "note", objectKind: "sticky", zone: "now", text: "remind me in 1 hr to call mom back", dueAt: now + 58 * MINUTE, whenLabel: "in 1 hr" },
    { n: 2, author: "maya", kind: "url", minutesAgo: 90, type: "place", objectKind: "postcard", zone: "now", title: "stonemill matcha", url: "https://www.stonemillmatcha.com", image: "seed-matcha", place: "stonemill matcha", latitude: 37.7637, longitude: -122.4217, startsAt: roundUp(now + 40 * MINUTE, 15) },
    { n: 3, author: "sam", kind: "image", minutesAgo: 600, type: "place", objectKind: "cutout", zone: "tonight", title: "tonkotsu ramen", image: "seed-ramen", place: "mensho tokyo", latitude: 37.7869, longitude: -122.4137, startsAt: Math.max(today + 19.5 * HOUR, roundUp(now + 2 * HOUR, 30)) },
    { n: 4, author: "alex", kind: "url", minutesAgo: 200, type: "event", objectKind: "postcard", zone: "tonight", title: "late show at the strand", url: "https://www.act-sf.org/the-strand", image: "seed-strand", place: "the strand theater", latitude: 37.7787, longitude: -122.4139, startsAt: Math.max(today + 21.75 * HOUR, roundUp(now + 3 * HOUR, 15)) },
    { n: 5, author: "panth", kind: "pdf", minutesAgo: 1440, type: "event", objectKind: "stub", zone: "thisWeekend", title: "chapel jazz night", place: "the chapel", price: 25, startsAt: saturday + 20 * HOUR },
    { n: 6, author: "sam", kind: "audio", minutesAgo: 300, type: "note", objectKind: "slip", zone: "thisWeekend", transcript: "the thrift spots on valencia, the one with the green awning first", startsAt: saturday + 11 * HOUR },
    { n: 7, author: "alex", kind: "text", minutesAgo: 2880, type: "event", objectKind: "sticky", zone: "thisWeekend", title: "sam's birthday dinner", text: "sam's birthday dinner at nopa saturday 7pm", place: "nopa", latitude: 37.7748, longitude: -122.4376, startsAt: saturday + 19 * HOUR, whenLabel: "saturday at 7pm", pinnedAt: now - 26 * HOUR },
    { n: 8, author: "maya", kind: "image", minutesAgo: 420, type: "event", objectKind: "polaroid", zone: "thisWeekend", title: "picnic at dolores", text: "picnic at dolores sunday, bring a blanket", image: "seed-dolores", place: "dolores park", latitude: 37.7596, longitude: -122.4269, startsAt: sunday + 13 * HOUR, pinnedAt: now - 3 * HOUR },
    { n: 9, author: "sam", kind: "video", minutesAgo: 4000, type: "mood", objectKind: "polaroid", zone: "vibes", title: "the warehouse show", url: "https://www.tiktok.com/@soundcheck/video/7311", image: "seed-concert" },
    { n: 10, author: "panth", kind: "url", minutesAgo: 9000, type: "place", objectKind: "postcard", zone: "someday", title: "green door books", url: "https://www.greendoorbooks.example", image: "seed-bookshop" },
    { n: 11, author: "alex", kind: "text", minutesAgo: 7000, type: "note", objectKind: "sticky", zone: "someday", text: "that pottery class maya mentioned", unsure: true },
    { n: 12, author: "maya", kind: "url", minutesAgo: 6000, type: "note", objectKind: "postcard", zone: "someday", title: "the best burritos in the mission", url: "https://sf.eater.com/maps/best-burritos-san-francisco", siteName: "eater sf" },
    { n: 13, author: "panth", kind: "url", minutesAgo: 3000, type: "song", objectKind: "record", zone: "vibes", title: "golden hour", url: "https://music.apple.com/us/album/golden-hour/1", image: "seed-album", artist: "kacey musgraves" },
    { n: 14, author: "alex", kind: "url", minutesAgo: 2500, type: "song", objectKind: "record", zone: "vibes", title: "pink pony club", url: "https://open.spotify.com/track/1k2pQc5i348DCHwbn5KTdc", image: "seed-pinkpony", artist: "chappell roan" },
    { n: 15, author: "maya", kind: "image", minutesAgo: 5000, type: "mood", objectKind: "polaroid", zone: "vibes", text: "soft pink everything", image: "seed-pinksky" },
    { n: 16, author: "panth", kind: "url", minutesAgo: 20000, type: "place", objectKind: "postcard", zone: "done", title: "the dumpling place", place: "dumpling home", doneFrom: "someday" },
  ];
}

const CONNECTED: [number, number][] = [[9, 14]];

export const sfCrew = internalMutation({
  args: { images: v.optional(v.record(v.string(), v.id("_storage"))) },
  returns: v.object({ created: v.number(), reset: v.number(), images: v.number(), unusedImages: v.number() }),
  handler: async (ctx, { images = {} }) => {
    const now = Date.now();
    for (const name of PEOPLE) await ensurePerson(ctx, personId(name), name);
    const board = await boardById(ctx, BOARD_ID);
    if (!board) {
      const taken = await ctx.db
        .query("boards")
        .withIndex("by_inviteCode", (q) => q.eq("inviteCode", INVITE_CODE))
        .first();
      if (taken) throw new ConvexError(`invite code ${INVITE_CODE} already belongs to ${taken.boardId}`);
      await ctx.db.insert("boards", { boardId: BOARD_ID, name: "sf crew", shared: true, inviteCode: INVITE_CODE, ownerId: personId("panth") });
    }
    for (const name of PEOPLE) await addMember(ctx, BOARD_ID, personId(name));

    const used = new Set<Id<"_storage">>();
    let created = 0;
    let reset = 0;
    for (const s of seedDrops(now)) {
      const clientId = seedClientId(s.n);
      const capturedAt = now - s.minutesAgo * MINUTE;
      const imageIds = s.image && images[s.image] ? [images[s.image]] : [];
      imageIds.forEach((id) => used.add(id));
      const hints = s.transcript || s.artist ? { transcript: s.transcript, artist: s.artist } : undefined;
      const words = ruleExtraction({ text: [s.title, s.text, s.transcript].filter(Boolean).join("\n"), url: s.url, capturedAt, utcOffsetMinutes: OFFSET });
      const anchor = s.dueAt ?? s.startsAt;
      const whenLabel = s.whenLabel ?? (anchor ? whenLabelFor(anchor, now, OFFSET) : undefined);
      const pickedZone = s.doneFrom ?? s.zone;
      const related = CONNECTED.flatMap(([a, b]) => (a === s.n ? [b] : b === s.n ? [a] : [])).map(seedClientId);
      const stage: Stage = { ran: "skipped", reason: "seeded for the demo" };
      const searchText = [
        s.title && `title: ${s.title}`,
        s.place && `place: ${s.place}`,
        whenLabel && `when: ${whenLabel}`,
        words.kindWords.length > 0 && `kind: ${words.kindWords.join(", ")}`,
        words.vibeWords.length > 0 && `vibe: ${words.vibeWords.join(", ")}`,
        s.text && `note: ${s.text}`,
        s.artist && `by: ${s.artist}`,
        s.transcript && `voice note: ${s.transcript}`,
        s.url && `link: ${s.url}`,
      ]
        .filter(Boolean)
        .join("\n");
      const drop = {
        boardId: BOARD_ID,
        authorId: personId(s.author),
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
        enrichment: s.url ? { provider: "seed", title: s.title, author: s.artist, siteName: s.siteName } : undefined,
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
        pinned: s.pinnedAt !== undefined,
        pinnedAt: s.pinnedAt,
        relatedClientIds: related,
        pipeline: { enrich: stage, extract: stage, remember: stage, decide: stage, connect: stage, startedAt: capturedAt, finishedAt: capturedAt },
        searchText,
        updatedAt: now,
      };
      const existing = await ctx.db
        .query("drops")
        .withIndex("by_clientId", (q) => q.eq("clientId", clientId))
        .unique();
      if (!existing) {
        await ctx.db.insert("drops", drop);
        created++;
        continue;
      }
      if (existing.boardId !== BOARD_ID) throw new ConvexError(`${clientId} is already on board ${existing.boardId}`);
      for (const old of existing.imageIds) if (!imageIds.includes(old)) await ctx.storage.delete(old);
      await ctx.db.replace("drops", existing._id, drop);
      reset++;
    }
    const unused = Object.values(images).filter((id) => !used.has(id));
    for (const id of unused) await ctx.storage.delete(id);
    return { created, reset, images: used.size, unusedImages: unused.length };
  },
});
