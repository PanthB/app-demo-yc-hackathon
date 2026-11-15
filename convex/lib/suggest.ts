type Saved = {
  url?: string;
  title?: string;
  extraction?: { title?: string; placeName?: string };
  hints?: { linkTitle?: string; placeName?: string };
  enrichment?: { title?: string };
};

export const linkKey = (url?: string) => {
  if (!url) return undefined;
  try {
    const u = new URL(url);
    return `${u.hostname.replace(/^www\./, "").toLowerCase()}${u.pathname.replace(/\/+$/, "")}`;
  } catch {
    return url.trim().toLowerCase();
  }
};

const placeKey = (d: Saved) => (d.hints?.placeName ?? d.extraction?.placeName)?.trim().toLowerCase() || undefined;

export function sameThing(a: Saved, b: Saved) {
  const link = linkKey(a.url);
  const place = placeKey(a);
  return (link !== undefined && link === linkKey(b.url)) || (place !== undefined && place === placeKey(b));
}

export const nameLabel = (name: string | undefined) => (!name || name === "me" ? "a friend" : name);

export function joinNames(names: string[]) {
  const unique = [...new Set(names)];
  if (unique.length <= 1) return unique[0] ?? "";
  return `${unique.slice(0, -1).join(", ")} and ${unique[unique.length - 1]}`;
}

export const socialLine = (names: string[], same: boolean) =>
  `${joinNames(names)} saved ${same ? "this too" : "something that goes with this"}.`;

const CLIP_HOSTS = /(^|\.)(tiktok\.com|instagram\.com|youtube\.com|youtu\.be)$/;

export function nounFor(d: { kind: string; url?: string; decision?: { type: string } }) {
  const type = d.decision?.type;
  if (type === "song") return "song";
  if (type === "event") return "plan";
  if (type === "place") return "spot";
  if (d.kind === "video" || CLIP_HOSTS.test(linkKey(d.url)?.split("/")[0] ?? "")) return "clip";
  if (d.kind === "image") return "photo";
  if (d.kind === "url") return "link";
  return "note";
}

export const sitsWithLine = (name: string, noun: string, reason: string) => `sits with ${name}'s ${noun}: ${reason}`;

export function goesWithLine(d: Saved) {
  const title = (d.extraction?.title ?? d.hints?.linkTitle ?? d.enrichment?.title)?.trim().toLowerCase();
  return title && title.length <= 40 ? `this goes with ${title.replace(/[.!?]+$/, "")}.` : undefined;
}
