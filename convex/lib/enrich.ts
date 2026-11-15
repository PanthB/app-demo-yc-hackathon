import type { Enrichment } from "../model";
import { hostOf } from "./rules";

const CRAWLER_UA = "facebookexternalhit/1.1";
const UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";

async function getJson(url: string) {
  const response = await fetch(url, { headers: { "User-Agent": UA }, signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error(`${new URL(url).host} ${response.status}`);
  return (await response.json()) as Record<string, unknown>;
}

const decode = (s: string) =>
  s
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#x([0-9a-f]+);/gi, (_, h: string) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d: string) => String.fromCodePoint(Number(d)))
    .trim();

async function pageMeta(url: string, userAgent = UA) {
  const response = await fetch(url, {
    headers: { "User-Agent": userAgent, Accept: "text/html" },
    redirect: "follow",
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new Error(`${hostOf(url)} ${response.status}`);
  const type = response.headers.get("content-type") ?? "";
  if (!type.includes("html")) return { contentType: type } as Record<string, string>;
  const html = (await response.text()).slice(0, 600_000);
  const meta: Record<string, string> = {};
  for (const tag of html.match(/<meta\s[^>]*>/gi) ?? []) {
    const key = tag.match(/(?:property|name)\s*=\s*["']([^"']+)["']/i)?.[1]?.toLowerCase();
    const content = tag.match(/content\s*=\s*["']([^"']*)["']/i)?.[1];
    if (key && content !== undefined && !(key in meta)) meta[key] = decode(content);
  }
  const title = html.match(/<title[^>]*>([^<]*)<\/title>/i)?.[1];
  if (title) meta["html:title"] = decode(title);
  return meta;
}

const str = (x: unknown) => (typeof x === "string" && x.trim() ? x.trim() : undefined);

const unquote = (s: string) => s.trim().replace(/^"([\s\S]*)"\.?$/, "$1").trim();

async function songFacts(title?: string, artist?: string) {
  if (!title) return { found: false };
  try {
    const found = await getJson(`https://api.deezer.com/search?limit=1&q=${encodeURIComponent([title, artist].filter(Boolean).join(" "))}`);
    const hit = (found.data as { id?: number; album?: { id?: number } }[] | undefined)?.[0];
    if (!hit?.id || !hit.album?.id) return { found: false };
    const [track, album] = await Promise.all([getJson(`https://api.deezer.com/track/${hit.id}`), getJson(`https://api.deezer.com/album/${hit.album.id}`)]);
    const bpm = typeof track.bpm === "number" && track.bpm > 0 ? Math.round(track.bpm * 10) / 10 : undefined;
    const genre = str((album.genres as { data?: { name?: string }[] } | undefined)?.data?.[0]?.name);
    const durationSec = typeof track.duration === "number" && track.duration > 0 ? track.duration : undefined;
    return { found: true, genre: genre?.toLowerCase(), bpm, durationSec };
  } catch {
    return { found: false };
  }
}

export function instagramPost(meta: Record<string, string>) {
  const titled = meta["og:title"]?.match(/^([\s\S]*?) on Instagram:\s*([\s\S]*)$/);
  const described = (meta["og:description"] ?? meta["description"])?.match(
    /^(?:[\d.,]+[KkMm]?\s+likes?,\s*[\d.,]+[KkMm]?\s+comments?\s+-\s+)?(\S+)\s+on\s+[A-Z][a-z]+\s+\d{1,2},\s+\d{4}\s*:\s*([\s\S]*)$/,
  );
  const caption = str(described ? unquote(described[2]) : titled ? unquote(titled[2]) : undefined);
  return {
    title: caption?.split("\n").find((line) => line.trim())?.trim().slice(0, 100),
    description: caption,
    author: str(titled?.[1]) ?? described?.[1],
  };
}

export async function enrichLink(url: string): Promise<Enrichment> {
  const host = hostOf(url) ?? "";
  if (/(^|\.)instagram\.com$/.test(host)) {
    const meta = await pageMeta(url, CRAWLER_UA).catch((): Record<string, string> => ({}));
    return { provider: "instagram og tags", ...instagramPost(meta), siteName: "Instagram", thumbnailUrl: meta["og:image"] };
  }
  if (/(^|\.)tiktok\.com$/.test(host)) {
    const [o, meta] = await Promise.all([
      getJson(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`).catch((): Record<string, unknown> => ({})),
      pageMeta(url, CRAWLER_UA).catch((): Record<string, string> => ({})),
    ]);
    return {
      provider: "tiktok oembed + og tags",
      title: str(o.title),
      description: meta["og:description"],
      author: str(o.author_name) ?? meta["og:title"]?.replace(/^TikTok\s*[·|-]\s*/i, ""),
      siteName: "TikTok",
      thumbnailUrl: str(o.thumbnail_url) ?? meta["og:image"],
    };
  }
  if (/(^|\.)(youtube\.com|youtu\.be)$/.test(host)) {
    const o = await getJson(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(url)}`);
    return { provider: "youtube oembed", title: str(o.title), author: str(o.author_name), siteName: "YouTube", thumbnailUrl: str(o.thumbnail_url) };
  }
  if (/(^|\.)spotify\.com$/.test(host)) {
    const [o, meta] = await Promise.all([
      getJson(`https://open.spotify.com/oembed?url=${encodeURIComponent(url)}`),
      pageMeta(url).catch((): Record<string, string> => ({})),
    ]);
    const description = meta["og:description"];
    const title = str(o.title) ?? meta["og:title"];
    const artist = meta["music:musician_description"] ?? description?.split(" · ")[0];
    const song = await songFacts(title, artist);
    return { provider: `spotify oembed + og tags${song.found ? " + deezer" : ""}`, title, author: artist, description, siteName: "Spotify", thumbnailUrl: str(o.thumbnail_url) ?? meta["og:image"], genre: song.genre, bpm: song.bpm, durationSec: song.durationSec };
  }
  const meta = await pageMeta(url);
  if (meta.contentType) return { provider: `direct file (${meta.contentType.split(";")[0]})`, siteName: host };
  if (/(^|\.)music\.apple\.com$/.test(host)) {
    const named = meta["og:title"]?.match(/^(.+) by (.+) on Apple\s+Music$/);
    const title = named?.[1] ?? meta["og:title"];
    const artist = named?.[2] ?? meta["music:musician_description"];
    const song = await songFacts(title, artist);
    return {
      provider: `apple music og tags${song.found ? " + deezer" : ""}`,
      title,
      description: meta["og:description"],
      author: artist,
      siteName: "Apple Music",
      thumbnailUrl: meta["og:image"],
      genre: song.genre,
      bpm: song.bpm,
      durationSec: song.durationSec,
    };
  }
  return {
    provider: "og tags",
    title: meta["og:title"] ?? meta["twitter:title"] ?? meta["html:title"],
    description: meta["og:description"] ?? meta["twitter:description"] ?? meta["description"],
    author: meta["music:musician_description"] ?? meta["author"],
    siteName: meta["og:site_name"] ?? host,
    thumbnailUrl: meta["og:image"] ?? meta["twitter:image"],
  };
}
