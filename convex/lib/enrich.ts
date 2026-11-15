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

export async function enrichLink(url: string): Promise<Enrichment> {
  const host = hostOf(url) ?? "";
  if (/(^|\.)(tiktok\.com|instagram\.com)$/.test(host)) {
    const tiktok = host.endsWith("tiktok.com");
    const [o, meta] = await Promise.all([
      tiktok ? getJson(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`).catch((): Record<string, unknown> => ({})) : Promise.resolve<Record<string, unknown>>({}),
      pageMeta(url, CRAWLER_UA).catch((): Record<string, string> => ({})),
    ]);
    const ogTitle = meta["og:title"]?.replace(/^(TikTok|Instagram)\s*[·|-]\s*/i, "");
    return {
      provider: tiktok ? "tiktok oembed + og tags" : "instagram og tags",
      title: str(o.title),
      description: meta["og:description"],
      author: str(o.author_name) ?? ogTitle,
      siteName: tiktok ? "TikTok" : "Instagram",
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
    const artist = meta["music:musician_description"] ?? description?.split(" · ")[0];
    return { provider: "spotify oembed + og tags", title: str(o.title) ?? meta["og:title"], author: artist, description, siteName: "Spotify", thumbnailUrl: str(o.thumbnail_url) ?? meta["og:image"] };
  }
  const meta = await pageMeta(url);
  if (meta.contentType) return { provider: `direct file (${meta.contentType.split(";")[0]})`, siteName: host };
  return {
    provider: /(^|\.)music\.apple\.com$/.test(host) ? "apple music og tags" : "og tags",
    title: meta["og:title"] ?? meta["twitter:title"] ?? meta["html:title"],
    description: meta["og:description"] ?? meta["twitter:description"] ?? meta["description"],
    author: meta["music:musician_description"] ?? meta["author"],
    siteName: meta["og:site_name"] ?? host,
    thumbnailUrl: meta["og:image"] ?? meta["twitter:image"],
  };
}
