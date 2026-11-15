export const FACETS = {
  mood: ["dreamy", "cozy", "upbeat", "moody", "wild", "calm"],
  time: ["morning", "golden hour", "late night"],
  setting: ["outdoors", "by the water", "food", "live music", "at home"],
  neighborhood: [
    "mission", "castro", "haight", "hayes valley", "nopa", "north beach", "chinatown", "japantown", "marina", "presidio",
    "golden gate park", "sunset", "richmond", "soma", "embarcadero", "dogpatch", "noe valley", "lands end", "tenderloin", "union square",
  ],
  genre: ["pop", "indie", "rock", "hip hop", "r&b", "electronic", "jazz", "folk", "country", "soul", "classical"],
  energy: ["slow", "steady", "high energy"],
} as const;

type Facet = keyof typeof FACETS;
const FACET_ORDER: Facet[] = ["mood", "time", "neighborhood", "setting", "genre", "energy"];
const WEIGHT: Record<Facet, number> = { mood: 1, neighborhood: 1, time: 0.8, setting: 0.8, genre: 0.6, energy: 0.4 };
const FACET_OF = new Map<string, Facet>(FACET_ORDER.flatMap((f) => FACETS[f].map((value): [string, Facet] => [value, f])));
const weightOf = (value: string) => WEIGHT[FACET_OF.get(value) ?? "energy"];

export const JOIN = 0.3;
const MAX_VIBES = 5;

const words = (list: string) => new RegExp(`(?:^|[^a-z])(?:${list})(?=$|[^a-z])`, "i");

const VALUE_WORDS: Record<string, RegExp> = {
  dreamy: words("dreamy|dreams?|ethereal|hazy|haze|pastel|magical|fairytale|unreal|soft pink|starry|whimsical"),
  cozy: words("cozy|cosy|warm|blanket|tea|bookshop|bookstore|books|candle|comfort|snug|homey"),
  upbeat: words("upbeat|fun|dance|dancing|party|happy|sunny|bright|vibrant|hype|joy|celebrat\\w*|birthday"),
  moody: words("moody|dark|fog|foggy|karl|rain|rainy|melancholy|sad|gloomy|noir|lonely"),
  wild: words("wild|rave|mosh|loud|chaos|chaotic|crazy|warehouse|insane|rowdy"),
  calm: words("calm|chill|quiet|peaceful|lazy|serene|relax\\w*|slow morning|meditat\\w*|stillness"),
  morning: words("morning|sunrise|breakfast|brunch|dawn|early bird|morning bun"),
  "golden hour": words("golden hour|sunset|dusk|golden light|magic hour|sundown"),
  "late night": words("late night|late-night|midnight|after dark|[1-4] ?am|nightlife|late show|nights?|after hours"),
  outdoors: words("park|hike|hiking|trail|picnic|outdoors?|garden|beach|viewpoint|camping|woods|forest|lands end|twin peaks|presidio|dolores|stroll|walk"),
  "by the water": words("beach|ocean|bay(?! ?area)|pier|waterfront|ferry|sutro|crissy field|golden gate bridge|sea|coast|shore|baker beach"),
  food: words("food|foodie|restaurant|ramen|burritos?|tacos?|taqueria|pizza|dumplings?|bakery|coffee|matcha|cafe|caf\u00e9|brunch|dinner|lunch|sushi|noodles?|eats?|snacks?|dessert|ice cream|croissant|morning bun|menu|bites?|tonkotsu"),
  "live music": words("concert|gig|live music|band|dj|dj set|venue|fillmore|the chapel|warfield|the independent|festival|on tour|jazz night|warehouse show|orchestra|setlist|live set"),
  "at home": words("at home|cooking|couch|vinyl|record player|bedroom|homemade|night in"),
  mission: words("mission|mission district|valencia|dolores|24th street|la taqueria"),
  castro: words("castro"),
  haight: words("haight|ashbury|amoeba"),
  "hayes valley": words("hayes valley|hayes st"),
  nopa: words("nopa|divisadero|alamo square|painted ladies"),
  "north beach": words("north beach|coit tower|washington square|city lights"),
  chinatown: words("chinatown"),
  japantown: words("japantown|japan town|kinokuniya|marufuku"),
  marina: words("marina|chestnut street|palace of fine arts"),
  presidio: words("presidio|crissy field|baker beach|tunnel tops"),
  "golden gate park": words("golden gate park|de young|conservatory of flowers|stow lake|japanese tea garden"),
  sunset: words("outer sunset|inner sunset|sunset district|ocean beach|judah"),
  richmond: words("richmond|clement street"),
  soma: words("soma|sfmoma|moscone|oracle park"),
  embarcadero: words("embarcadero|ferry building|exploratorium"),
  dogpatch: words("dogpatch|chase center"),
  "noe valley": words("noe valley"),
  "lands end": words("lands end|sutro baths|sutro"),
  tenderloin: words("tenderloin"),
  "union square": words("union square"),
};

const CENTERS: [string, number, number][] = [
  ["mission", 37.7599, -122.4148], ["castro", 37.7609, -122.435], ["haight", 37.7692, -122.4481], ["hayes valley", 37.7759, -122.4245],
  ["nopa", 37.7765, -122.4376], ["north beach", 37.8061, -122.4103], ["chinatown", 37.7941, -122.4078], ["japantown", 37.7853, -122.4298],
  ["marina", 37.8037, -122.4368], ["presidio", 37.7989, -122.4662], ["golden gate park", 37.7694, -122.4862], ["sunset", 37.7535, -122.495],
  ["richmond", 37.78, -122.483], ["soma", 37.7785, -122.4056], ["embarcadero", 37.7955, -122.3937], ["dogpatch", 37.76, -122.388],
  ["noe valley", 37.7502, -122.4337], ["lands end", 37.7802, -122.5115], ["tenderloin", 37.7847, -122.4145], ["union square", 37.788, -122.4075],
];

const GENRES: [RegExp, string][] = [
  [/alternative|indie/i, "indie"], [/r&b|rnb/i, "r&b"], [/rap|hip ?hop/i, "hip hop"], [/dance|electro|techno|house/i, "electronic"],
  [/soul|funk/i, "soul"], [/jazz/i, "jazz"], [/folk|singer|songwriter/i, "folk"], [/country/i, "country"], [/classical|opera/i, "classical"],
  [/rock|metal|punk/i, "rock"], [/pop/i, "pop"],
];
const GENRE_MOOD: Record<string, string[]> = {
  pop: ["upbeat"], indie: ["dreamy"], "r&b": ["moody", "late night"], electronic: ["wild", "late night"], soul: ["cozy"],
  jazz: ["cozy", "late night"], folk: ["calm"], country: ["calm"], classical: ["calm"], "hip hop": ["upbeat"], rock: [],
};
const SLOW_GENRES = new Set(["r&b", "soul", "jazz", "folk", "country", "classical"]);

export const genreFor = (deezerGenre?: string) => GENRES.find(([re]) => deezerGenre && re.test(deezerGenre))?.[1];

function energyFor(genre: string | undefined, bpm: number | undefined) {
  if (bpm && bpm > 0) {
    const halfTime = genre !== "electronic" && (bpm > 140 || (genre !== undefined && SLOW_GENRES.has(genre) && bpm > 125));
    const tempo = halfTime ? bpm / 2 : bpm;
    return tempo < 95 ? "slow" : tempo <= 125 ? "steady" : "high energy";
  }
  if (!genre) return undefined;
  if (genre === "electronic") return "high energy";
  return SLOW_GENRES.has(genre) ? "slow" : "steady";
}

function nearestNeighborhood(latitude: number, longitude: number) {
  const km = (lat: number, lng: number) => Math.hypot((lat - latitude) * 111, (lng - longitude) * 88);
  const [best] = [...CENTERS].sort((a, b) => km(a[1], a[2]) - km(b[1], b[2]));
  return km(best[1], best[2]) <= 1.2 ? best[0] : undefined;
}

export function ruleVibes(input: {
  text: string;
  isSong: boolean;
  genre?: string;
  bpm?: number;
  startsAt?: number;
  utcOffsetMinutes: number;
  place?: { latitude: number; longitude: number };
}) {
  const found = new Set(Object.entries(VALUE_WORDS).filter(([, re]) => re.test(input.text)).map(([value]) => value));
  if (found.has("golden hour") || found.has("morning")) found.delete("late night");
  if (input.startsAt !== undefined) {
    const hour = new Date(input.startsAt + input.utcOffsetMinutes * 60_000).getUTCHours();
    if (hour >= 5 && hour < 11) found.add("morning");
    else if (hour >= 17 && hour < 20) found.add("golden hour");
    else if (hour >= 21 || hour < 4) found.add("late night");
  }
  if (input.place && ![...found].some((v) => FACET_OF.get(v) === "neighborhood")) {
    const hood = nearestNeighborhood(input.place.latitude, input.place.longitude);
    if (hood) found.add(hood);
  }
  if (input.isSong) {
    for (const v of [...found]) if (FACET_OF.get(v) === "neighborhood") found.delete(v);
    const genre = genreFor(input.genre);
    const energy = energyFor(genre, input.bpm);
    if (genre) found.add(genre);
    if (energy) found.add(energy);
    const hasMood = [...found].some((v) => FACET_OF.get(v) === "mood");
    for (const v of genre ? GENRE_MOOD[genre] : []) if (FACET_OF.get(v) !== "mood" || !hasMood) found.add(v);
    if (![...found].some((v) => FACET_OF.get(v) === "mood")) {
      if (energy === "high energy") found.add("upbeat");
      if (energy === "slow") found.add("calm");
    }
  }
  return orderVibes([...found]);
}

export function orderVibes(values: string[]) {
  const rank = (v: string) => FACET_ORDER.indexOf(FACET_OF.get(v) ?? "energy");
  const perFacet = new Map<Facet, number>();
  return [...new Set(values)]
    .filter((v) => FACET_OF.has(v))
    .sort((a, b) => rank(a) - rank(b))
    .filter((v) => {
      const facet = FACET_OF.get(v)!;
      const count = perFacet.get(facet) ?? 0;
      perFacet.set(facet, count + 1);
      return count < 2;
    })
    .slice(0, MAX_VIBES);
}

export const facetValues = (facet: "mood" | "time" | "setting") => [...FACETS[facet]];
export const facetOf = (value: string) => FACET_OF.get(value);

export function similarity(a: string[], b: string[]) {
  const all = new Set([...a, ...b]);
  if (all.size === 0) return 0;
  let shared = 0;
  let total = 0;
  for (const v of all) {
    total += weightOf(v);
    if (a.includes(v) && b.includes(v)) shared += weightOf(v);
  }
  return shared / total;
}

const PLACE_PHRASE: Record<string, string> = {
  mission: "in the mission", castro: "in the castro", haight: "in the haight", marina: "in the marina", presidio: "in the presidio",
  sunset: "in the sunset", richmond: "in the richmond", tenderloin: "in the tenderloin", embarcadero: "on the embarcadero",
  "lands end": "at lands end", "union square": "at union square",
};
const phrase = (v: string) => (FACET_OF.get(v) === "neighborhood" ? (PLACE_PHRASE[v] ?? `in ${v}`) : v);
const byWeight = (values: string[]) => [...values].sort((a, b) => weightOf(b) - weightOf(a) || FACET_ORDER.indexOf(FACET_OF.get(a)!) - FACET_ORDER.indexOf(FACET_OF.get(b)!));

export const reasonFor = (a: string[], b: string[]) => {
  const shared = byWeight(a.filter((v) => b.includes(v))).slice(0, 2);
  return shared.length ? `both ${shared.map(phrase).join(", ")}.` : undefined;
};

export type ClusterItem = { clientId: string; vibes: string[]; capturedAt: number; previousClusterId?: string; jevClusterId?: string };
export type Placement = { clusterId: string; clusterLabel: string; neighbors: { clientId: string; reason: string }[] };

export function clusterBoard(items: ClusterItem[]): Map<string, Placement> {
  const sorted = [...items].sort((a, b) => a.capturedAt - b.capturedAt || a.clientId.localeCompare(b.clientId));
  const n = sorted.length;
  const sim = sorted.map((a) => sorted.map((b) => similarity(a.vibes, b.vibes)));
  const groups: number[][] = [];
  const meanTo = (i: number, group: number[]) => {
    const others = group.filter((j) => j !== i);
    return others.length ? others.reduce((s, j) => s + sim[i][j], 0) / others.length : -1;
  };
  const best = (i: number) => {
    let at = -1;
    let score = JOIN;
    groups.forEach((g, k) => {
      const s = meanTo(i, g);
      if (s >= score) [at, score] = [k, s];
    });
    return at;
  };
  const pinned = new Set(
    sorted
      .map((x, i) => (x.jevClusterId && sorted.some((y, j) => j !== i && !y.jevClusterId && y.previousClusterId === x.jevClusterId) ? i : -1))
      .filter((i) => i >= 0),
  );
  for (let i = 0; i < n; i++) {
    if (pinned.has(i)) continue;
    const k = best(i);
    if (k >= 0) groups[k].push(i);
    else groups.push([i]);
  }
  for (let pass = 0; pass < 2; pass++) {
    for (let i = 0; i < n; i++) {
      if (pinned.has(i)) continue;
      const from = groups.findIndex((g) => g.includes(i));
      const stay = meanTo(i, groups[from]);
      const k = best(i);
      if (k === from || (k >= 0 && meanTo(i, groups[k]) <= stay)) continue;
      groups[from] = groups[from].filter((j) => j !== i);
      if (k >= 0) groups[k].push(i);
      else groups.push([i]);
    }
    for (let k = groups.length - 1; k >= 0; k--) if (groups[k].length === 0) groups.splice(k, 1);
  }
  for (const i of pinned) {
    const want = sorted[i].jevClusterId;
    const counts = groups.map((g) => g.filter((j) => sorted[j].previousClusterId === want).length);
    const k = counts.indexOf(Math.max(0, ...counts));
    if (counts[k] > 0) groups[k].push(i);
    else groups.push([i]);
  }

  const groupOf = new Map<number, number>();
  groups.forEach((g, k) => g.forEach((i) => groupOf.set(i, k)));
  const claimed = new Set<string>();
  const ids = new Map<number, string>();
  [...groups.keys()]
    .sort((a, b) => groups[b].length - groups[a].length)
    .forEach((k) => {
      const counts = new Map<string, number>();
      for (const i of groups[k]) {
        const prev = sorted[i].previousClusterId;
        if (prev && !claimed.has(prev)) counts.set(prev, (counts.get(prev) ?? 0) + 1);
      }
      const [reused] = [...counts.entries()].sort((a, b) => b[1] - a[1]);
      let id = reused && reused[1] * 2 >= groups[k].length ? reused[0] : sorted[Math.min(...groups[k])].clientId;
      while (claimed.has(id)) id = `${id}+`;
      claimed.add(id);
      ids.set(k, id);
    });

  const labels = groups.map((g) => {
    const counts = new Map<string, number>();
    for (const i of g) for (const v of sorted[i].vibes) counts.set(v, (counts.get(v) ?? 0) + 1);
    const common = [...counts.entries()].filter(([, c]) => c * 2 >= g.length || g.length === 1);
    const pool = common.length ? common : [...counts.entries()];
    return pool
      .sort((a, b) => b[1] * weightOf(b[0]) - a[1] * weightOf(a[0]) || FACET_ORDER.indexOf(FACET_OF.get(a[0])!) - FACET_ORDER.indexOf(FACET_OF.get(b[0])!))
      .slice(0, 2)
      .map(([v]) => phrase(v))
      .join(", ");
  });

  const placements = new Map<string, Placement>();
  for (let i = 0; i < n; i++) {
    const k = groupOf.get(i)!;
    const neighbors = sorted
      .map((_, j) => j)
      .filter((j) => j !== i && sim[i][j] >= JOIN)
      .sort((a, b) => Number(groupOf.get(b) === k) - Number(groupOf.get(a) === k) || sim[i][b] - sim[i][a])
      .slice(0, 2)
      .map((j) => ({ clientId: sorted[j].clientId, reason: reasonFor(sorted[i].vibes, sorted[j].vibes)! }));
    placements.set(sorted[i].clientId, { clusterId: ids.get(k)!, clusterLabel: labels[k], neighbors });
  }
  return placements;
}
