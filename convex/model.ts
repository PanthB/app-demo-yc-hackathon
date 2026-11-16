import { v, type Infer } from "convex/values";

export const zone = v.union(
  v.literal("now"),
  v.literal("tonight"),
  v.literal("thisWeekend"),
  v.literal("someday"),
  v.literal("vibes"),
  v.literal("done"),
);
export const dropType = v.union(
  v.literal("place"),
  v.literal("event"),
  v.literal("song"),
  v.literal("mood"),
  v.literal("note"),
);
export const objectKind = v.union(
  v.literal("cutout"),
  v.literal("polaroid"),
  v.literal("record"),
  v.literal("slip"),
  v.literal("sticky"),
  v.literal("stub"),
  v.literal("postcard"),
);
export const emphasis = v.union(
  v.literal("normal"),
  v.literal("grow"),
  v.literal("pulseOnce"),
  v.literal("curl"),
);
export const status = v.union(
  v.literal("pending"),
  v.literal("processed"),
  v.literal("failed"),
);
export const sourceKind = v.union(
  v.literal("url"),
  v.literal("image"),
  v.literal("video"),
  v.literal("audio"),
  v.literal("text"),
  v.literal("pdf"),
);
export const mode = v.union(v.literal("planning"), v.literal("wandering"));

export const stage = v.object({
  ran: v.union(
    v.literal("pending"),
    v.literal("done"),
    v.literal("rules"),
    v.literal("skipped"),
  ),
  by: v.optional(v.string()),
  reason: v.optional(v.string()),
});

export const pipeline = v.object({
  enrich: stage,
  extract: stage,
  remember: stage,
  decide: stage,
  connect: stage,
  startedAt: v.optional(v.number()),
  finishedAt: v.optional(v.number()),
  error: v.optional(v.string()),
});

export const hints = v.object({
  linkTitle: v.optional(v.string()),
  artist: v.optional(v.string()),
  transcript: v.optional(v.string()),
  pdfText: v.optional(v.string()),
  placeName: v.optional(v.string()),
  dueAt: v.optional(v.number()),
});

export const enrichment = v.object({
  provider: v.string(),
  title: v.optional(v.string()),
  description: v.optional(v.string()),
  author: v.optional(v.string()),
  siteName: v.optional(v.string()),
  thumbnailUrl: v.optional(v.string()),
  genre: v.optional(v.string()),
  bpm: v.optional(v.number()),
  durationSec: v.optional(v.number()),
});

export const neighbor = v.object({ clientId: v.string(), reason: v.string() });

export const extraction = v.object({
  title: v.optional(v.string()),
  placeName: v.optional(v.string()),
  area: v.optional(v.string()),
  startsAt: v.optional(v.number()),
  dueAt: v.optional(v.number()),
  whenLabel: v.optional(v.string()),
  price: v.optional(v.number()),
  kindWords: v.array(v.string()),
  category: v.optional(v.string()),
  vibeWords: v.array(v.string()),
  minutesThere: v.optional(v.number()),
  confidence: v.number(),
  fieldConfidence: v.optional(v.record(v.string(), v.number())),
});

export const decision = v.object({
  type: dropType,
  zone: zone,
  objectKind: objectKind,
  emphasis: emphasis,
  unsure: v.boolean(),
  typeProbabilities: v.record(v.string(), v.number()),
  zoneProbabilities: v.record(v.string(), v.number()),
});

export const PALETTE = ["orange", "blue", "green", "pink", "teal", "indigo", "yellow", "red"];

export const member = v.object({
  personId: v.string(),
  name: v.string(),
  color: v.string(),
  joinedAt: v.number(),
});

export const boardView = v.object({
  boardId: v.string(),
  name: v.string(),
  shared: v.boolean(),
  inviteCode: v.optional(v.string()),
  ownerId: v.string(),
  members: v.array(member),
  createdAt: v.number(),
});

export const personView = v.object({
  personId: v.string(),
  name: v.string(),
  personalBoardId: v.string(),
  recsMedia: v.boolean(),
  recsEvents: v.boolean(),
});

export const dropFields = {
  boardId: v.string(),
  authorId: v.string(),
  clientId: v.string(),
  kind: sourceKind,
  text: v.optional(v.string()),
  url: v.optional(v.string()),
  imageIds: v.array(v.id("_storage")),
  capturedAt: v.number(),
  utcOffsetMinutes: v.number(),
  latitude: v.optional(v.number()),
  longitude: v.optional(v.number()),
  hints: v.optional(hints),
  status: status,
  enrichment: v.optional(enrichment),
  extraction: v.optional(extraction),
  decision: v.optional(decision),
  zone: v.optional(zone),
  zoneSetByUser: v.boolean(),
  previousZone: v.optional(zone),
  pinned: v.boolean(),
  pinnedAt: v.optional(v.number()),
  suggestion: v.optional(v.string()),
  vibes: v.optional(v.array(v.string())),
  userKind: v.optional(v.string()),
  autoKind: v.optional(v.string()),
  clusterId: v.optional(v.string()),
  clusterLabel: v.optional(v.string()),
  neighbors: v.optional(v.array(neighbor)),
  jevClusterId: v.optional(v.string()),
  found: v.optional(v.object({ inspiredBy: v.array(v.string()), foundAt: v.number(), dismissedAt: v.optional(v.number()) })),
  relatedClientIds: v.array(v.string()),
  pipeline: pipeline,
  searchText: v.optional(v.string()),
  updatedAt: v.number(),
};

export const dropDoc = v.object({
  _id: v.id("drops"),
  _creationTime: v.number(),
  ...dropFields,
});

export const dropView = v.object({
  _id: v.id("drops"),
  _creationTime: v.number(),
  ...dropFields,
  title: v.optional(v.string()),
  thumbnailUrl: v.optional(v.string()),
  imageUrls: v.array(v.string()),
  authorName: v.optional(v.string()),
  authorColor: v.optional(v.string()),
  vibes: v.array(v.string()),
  groupKind: v.optional(v.string()),
  neighbors: v.array(neighbor),
});

export const nullable = <T extends Parameters<typeof v.optional>[0]>(x: T) =>
  v.optional(v.union(x, v.null()));

export type Zone = Infer<typeof zone>;
export type DropType = Infer<typeof dropType>;
export type ObjectKind = Infer<typeof objectKind>;
export type Emphasis = Infer<typeof emphasis>;
export type SourceKind = Infer<typeof sourceKind>;
export type Stage = Infer<typeof stage>;
export type Pipeline = Infer<typeof pipeline>;
export type Hints = Infer<typeof hints>;
export type Enrichment = Infer<typeof enrichment>;
export type Extraction = Infer<typeof extraction>;
export type Decision = Infer<typeof decision>;
export type Mode = Infer<typeof mode>;
