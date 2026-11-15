import * as chrono from "chrono-node";
import type {
  Decision,
  DropType,
  Emphasis,
  Enrichment,
  Extraction,
  Hints,
  ObjectKind,
  SourceKind,
  Zone,
} from "../model";

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const MONTHS = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

export const DROP_TYPES: DropType[] = ["place", "event", "song", "mood", "note"];
export const TIME_ZONES: Zone[] = ["now", "tonight", "thisWeekend", "someday", "vibes"];

const KIND_WORDS = ["ramen", "sushi", "tacos", "pizza", "burger", "noodles", "dumplings", "bakery", "brunch", "dinner", "lunch", "coffee", "matcha", "cafe", "bar", "cocktails", "wine", "restaurant", "concert", "show", "festival", "party", "gig", "dj set", "comedy", "museum", "gallery", "exhibit", "movie", "screening", "game", "class", "hike", "trail", "beach", "park", "thrift", "vintage", "market", "shop", "store", "bookstore", "record store", "outfit", "song", "album", "playlist", "tickets", "trip"];
const VIBE_WORDS = ["cozy", "chill", "loud", "quiet", "sunny", "moody", "dreamy", "cute", "fun", "romantic", "late night", "lazy", "fancy", "cheap", "vintage", "aesthetic", "calm", "wild", "sweet", "retro", "minimal", "warm", "golden hour", "rainy", "summer", "fall", "winter", "spring"];
const EVENT_WORDS = /\b(concert|show|tickets?|festival|party|gig|screening|class|tour|exhibit(ion)?|opening|dj|live|match|game|comedy|premiere|meetup|wedding|birthday)\b/i;
const PLACE_WORDS = /\b(ramen|sushi|tacos?|pizza|burgers?|noodles?|dumplings?|bakery|brunch|dinner|lunch|coffee|matcha|cafe|caf\u00e9|bar|restaurant|museum|gallery|park|beach|hike|trail|thrift|vintage|market|shop|store|bookstore|spot)\b/i;
const MUSIC_HOSTS = /(^|\.)(spotify\.com|music\.apple\.com|soundcloud\.com|bandcamp\.com|tidal\.com)$/;

export const isMusicLink = (url?: string) => MUSIC_HOSTS.test(hostOf(url) ?? "");

export const hostOf = (url?: string) => {
  if (!url) return undefined;
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return undefined;
  }
};

const local = (t: number, offset: number) => new Date(t + offset * 60_000);
const localMidnight = (t: number, offset: number) => {
  const d = local(t, offset);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
};

export function localStamp(t: number, offset: number) {
  const d = local(t, offset);
  const iso = d.toISOString().slice(0, 16).replace("T", " ");
  return `${iso} (${WEEKDAYS[d.getUTCDay()]})`;
}

export const localDate = (t: number, offset: number) =>
  local(t, offset).toISOString().slice(0, 10);

export function fromLocalIso(value: string, offset: number) {
  if (/[zZ]|[+-]\d\d:?\d\d$/.test(value)) return Date.parse(value);
  const [date, time = "00:00:00"] = value.split("T");
  const [y, m, d] = date.split("-").map(Number);
  const [hh, mm, ss] = time.split(":").map(Number);
  const utc = Date.UTC(y, m - 1, d, hh || 0, mm || 0, ss || 0) - offset * 60_000;
  return Number.isNaN(utc) ? undefined : utc;
}

function clock(t: number, offset: number) {
  const d = local(t, offset);
  const h = d.getUTCHours();
  const m = d.getUTCMinutes();
  const suffix = h < 12 ? "am" : "pm";
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${hour12}${suffix}` : `${hour12}:${String(m).padStart(2, "0")}${suffix}`;
}

export function whenLabelFor(at: number, now: number, offset: number, dayKnown = true, hourKnown = true) {
  const minutes = Math.round((at - now) / 60_000);
  if (minutes >= 0 && minutes < 60) return `in ${Math.max(minutes, 1)} min`;
  if (minutes >= 60 && minutes < 180) return `in ${Math.round(minutes / 60)} hr`;
  const d = local(at, offset);
  const month = MONTHS[d.getUTCMonth()];
  if (!dayKnown) return `sometime in ${month}`;
  const daysAhead = Math.round((localMidnight(at, offset) - localMidnight(now, offset)) / DAY);
  const time = hourKnown ? ` at ${clock(at, offset)}` : "";
  if (daysAhead === 0) return d.getUTCHours() >= 17 ? `tonight${time}` : `today${time}`;
  if (daysAhead === 1) return `tomorrow${time}`;
  if (daysAhead > 1 && daysAhead < 7) return `${WEEKDAYS[d.getUTCDay()]}${time}`;
  return `${month} ${d.getUTCDate()}${time}`;
}

export function zoneForTime(at: number, now: number, offset: number): Zone {
  const diff = at - now;
  if (diff < -6 * HOUR) return "someday";
  if (diff <= 3 * HOUR) return "now";
  const daysAhead = Math.round((localMidnight(at, offset) - localMidnight(now, offset)) / DAY);
  if (daysAhead === 0) return "tonight";
  const d = local(at, offset);
  const day = d.getUTCDay();
  const weekendish = day === 6 || day === 0 || (day === 5 && d.getUTCHours() >= 17);
  if (daysAhead <= 7 && weekendish) return "thisWeekend";
  return "someday";
}

export function corpus(text: string | undefined, url: string | undefined, hints: Hints | undefined, enrichment: Enrichment | undefined) {
  return [
    text,
    hints?.linkTitle,
    hints?.artist,
    hints?.placeName,
    hints?.transcript,
    hints?.pdfText?.slice(0, 4000),
    enrichment?.title,
    enrichment?.author,
    enrichment?.description,
    url,
  ]
    .filter((s): s is string => Boolean(s && s.trim()))
    .join("\n");
}

const SMALL_NUMBERS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"];
const TENS: Record<string, number> = { twenty: 20, thirty: 30, forty: 40, fifty: 50, sixty: 60 };
const NUMBER_WORDS = new RegExp(
  `\\b(?:(${Object.keys(TENS).join("|")})(?:[\\s-](${SMALL_NUMBERS.slice(1, 10).join("|")}))?|(${SMALL_NUMBERS.join("|")}))(?=\\s+(?:mins?|minutes?|hrs?|hours?|days?|weeks?)\\b)`,
  "gi",
);
const COUNTDOWN = /^(?:in|within)\s+(?:\d|an?\b|half\b|a\s+few\b|a\s+couple\b)/i;
const BARE_TIME_OF_DAY = /^(?:the\s+)?(?:morning|afternoon|evening|night|noon|midnight)$/i;

const withDigits = (s: string) =>
  s.replace(NUMBER_WORDS, (_, tens?: string, ones?: string, small?: string) =>
    String(tens ? TENS[tens.toLowerCase()] + (ones ? SMALL_NUMBERS.indexOf(ones.toLowerCase()) : 0) : SMALL_NUMBERS.indexOf(small!.toLowerCase())),
  );

const pickWords = (haystack: string, words: string[]) =>
  words.filter((w) => new RegExp(`\\b${w}\\b`, "i").test(haystack));

export function ruleExtraction(args: {
  text?: string;
  url?: string;
  hints?: Hints;
  enrichment?: Enrichment;
  capturedAt: number;
  utcOffsetMinutes: number;
}): Extraction {
  const { text, url, hints, enrichment, capturedAt, utcOffsetMinutes } = args;
  const body = corpus(text, url, hints, enrichment);
  const host = hostOf(url);
  const linkText = host && MUSIC_HOSTS.test(host) ? [] : [enrichment?.title, enrichment?.description];
  const timeSource = withDigits([text, hints?.transcript, hints?.pdfText?.slice(0, 4000), ...linkText].filter(Boolean).join("\n"));
  const parsed = chrono.parse(timeSource, { instant: new Date(capturedAt), timezone: utcOffsetMinutes }, { forwardDate: true }).find((r) => !BARE_TIME_OF_DAY.test(r.text.trim()));
  const at = parsed?.start.date().getTime();
  const isCountdown = Boolean(parsed && COUNTDOWN.test(parsed.text));
  const dueAt = hints?.dueAt ?? (isCountdown ? at : undefined);
  const startsAt = isCountdown ? undefined : at;
  const anchor = dueAt ?? startsAt;
  const monthOnly = Boolean(parsed && parsed.start.isCertain("month") && !parsed.start.isCertain("day") && !parsed.start.isCertain("weekday"));
  const whenLabel = anchor
    ? whenLabelFor(anchor, capturedAt, utcOffsetMinutes, !monthOnly, parsed ? parsed.start.isCertain("hour") : true)
    : undefined;
  const price = body.match(/\$\s?(\d+(?:\.\d{1,2})?)/);
  const placeMatch = (text ?? "").match(/\b(?:at|@)\s+([A-Z][\w'&.-]*(?:\s+[A-Z][\w'&.-]*){0,3})/);
  const firstLine = (text ?? hints?.transcript ?? hints?.pdfText ?? "").split("\n")[0].trim();
  const title = hints?.linkTitle ?? enrichment?.title ?? (firstLine ? firstLine.slice(0, 80) : undefined);
  return {
    title,
    placeName: hints?.placeName ?? placeMatch?.[1],
    startsAt,
    dueAt,
    whenLabel,
    price: price ? Number(price[1]) : undefined,
    kindWords: pickWords(body, KIND_WORDS),
    vibeWords: pickWords(body, VIBE_WORDS),
    confidence: 0.3,
  };
}

export function ruleType(kind: SourceKind, url: string | undefined, ex: Extraction, body: string): DropType {
  const host = hostOf(url);
  if (host && MUSIC_HOSTS.test(host)) return "song";
  if (ex.dueAt) return "note";
  if (kind === "audio") return "note";
  if (ex.startsAt && (EVENT_WORDS.test(body) || kind === "pdf")) return "event";
  if (ex.placeName || PLACE_WORDS.test(body)) return "place";
  if (ex.startsAt) return "event";
  if (kind === "text") return "note";
  return "mood";
}

export function objectKindFor(type: DropType, kind: SourceKind, hasImages: boolean): ObjectKind {
  if (type === "song") return "record";
  if (type === "event") return "stub";
  if (type === "note") return kind === "audio" ? "slip" : "sticky";
  if (type === "place") return hasImages ? "cutout" : "postcard";
  return hasImages ? "polaroid" : "postcard";
}

export function ruleZone(type: DropType, ex: Extraction, now: number, offset: number): { zone: Zone; unsure: boolean } {
  const at = ex.dueAt ?? ex.startsAt;
  if (at !== undefined) return { zone: zoneForTime(at, now, offset), unsure: false };
  if (type === "song" || type === "mood") return { zone: "vibes", unsure: false };
  return { zone: "someday", unsure: true };
}

export function ruleEmphasis(zone: Zone, connected: boolean): Emphasis {
  if (zone === "now") return "grow";
  return connected ? "pulseOnce" : "normal";
}

export function spread<T extends string>(options: T[], chosen: T, weight: number) {
  const rest = (1 - weight) / (options.length - 1);
  return Object.fromEntries(options.map((o) => [o, o === chosen ? weight : rest])) as Record<string, number>;
}

export function ruleDecision(kind: SourceKind, url: string | undefined, ex: Extraction, body: string, hasImages: boolean, now: number, offset: number, connected: boolean): Decision {
  const type = ruleType(kind, url, ex, body);
  const { zone, unsure } = ruleZone(type, ex, now, offset);
  return {
    type,
    zone,
    objectKind: objectKindFor(type, kind, hasImages),
    emphasis: ruleEmphasis(zone, connected),
    unsure,
    typeProbabilities: spread(DROP_TYPES, type, 0.6),
    zoneProbabilities: spread(TIME_ZONES, zone, unsure ? 0.4 : 0.6),
  };
}

const STOP = new Set([
  "the", "and", "for", "with", "this", "that", "from", "you", "your", "are", "was", "have", "just", "about", "into", "should", "will", "can", "out", "our", "its", "but", "not", "all", "get", "got", "lets", "let", "want", "need", "remind",
  "http", "https", "www", "com", "jpg", "jpeg", "png",
  "sometime", "tonight", "today", "tomorrow", "weekend", "next", "min", "mins", "minutes", "hour", "hours", "hrs", "night", "morning", "evening",
  ...MONTHS,
  ...WEEKDAYS,
]);

export function keywords(s: string) {
  return new Set(
    s
      .split("\n")
      .filter((line) => !/^(when|link|thumbnail):/.test(line))
      .map((line) => line.replace(/^[a-z ]+:\s*/, ""))
      .join(" ")
      .toLowerCase()
      .split(/[^a-z0-9\u00c0-\u024f]+/)
      .filter((w) => w.length > 2 && !/^\d+$/.test(w) && !STOP.has(w)),
  );
}

export function overlap(a: Set<string>, b: Set<string>) {
  if (a.size === 0 || b.size === 0) return 0;
  let shared = 0;
  for (const w of a) if (b.has(w)) shared++;
  return shared < 2 ? 0 : shared / Math.min(a.size, b.size);
}
