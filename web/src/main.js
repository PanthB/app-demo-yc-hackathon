import { ConvexClient } from "convex/browser";
import { anyApi } from "convex/server";
import { icon } from "./icons.js";

const DEPLOYMENT = "https://adorable-coyote-696.convex.cloud";
const SF_CREW = { id: "sf-crew" };
const SF_CREW_LEDE = "a board some friends keep in resona. when one of them saves something on their phone, it shows up here.";
const GUEST_LEDE = "paste a link from tiktok, instagram, spotify, youtube or maps, and watch it get read and placed.";
const GUEST_KEY = "moments-guest";
const GUEST_LIMIT = 8;

const PALETTE = {
  orange: "#ff9f0a",
  blue: "#0a84ff",
  green: "#30d158",
  pink: "#ff375f",
  teal: "#40c8e0",
  indigo: "#5e5ce6",
  yellow: "#ffd60a",
  red: "#ff453a",
};
const PALETTE_ORDER = Object.keys(PALETTE);
const TIME_ORDER = ["now", "tonight", "thisWeekend", "someday"];
const TIME_LABELS = { now: "now", tonight: "tonight", thisWeekend: "this weekend", someday: "someday", anytime: "anytime" };
const CLIP_SITES = [
  ["tiktok.com", "tiktok"],
  ["youtube.com", "youtube"],
  ["youtu.be", "youtube"],
  ["vimeo.com", "vimeo"],
  ["instagram.com", "instagram"],
];

const board = document.getElementById("board");
const titleEl = document.getElementById("title");
const ledeEl = document.getElementById("lede");
const otherBoardEl = document.getElementById("other-board");
const addForm = document.getElementById("add");
const addInput = addForm.querySelector("input");
const addButton = addForm.querySelector("button");
const addNote = document.getElementById("add-note");
const membersEl = document.getElementById("members");
const liveEl = document.getElementById("live");
const toastEl = document.getElementById("toast");
const switchButtons = [...document.querySelectorAll(".switch button")];
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

const state = { board: null, drops: null, ideas: [], view: "mood" };
const cards = new Map();
const ideaRows = new Map();
const arrivals = new Set();
let known = null;
let toastTimer = 0;
let subscriptions = [];
let guest = loadGuest();

const client = new ConvexClient(DEPLOYMENT);
window.addEventListener("hashchange", route);
route();

async function route() {
  if (location.hash !== "#try") {
    openBoard(SF_CREW);
    return;
  }
  if (!guest) {
    openBoard(null);
    showStatus("making your board…");
    try {
      guest = await makeGuest();
    } catch {
      showStatus("your board didn't get made. reload to try again.");
      return;
    }
    if (location.hash !== "#try") return;
  }
  openBoard({ id: guest.boardId, personId: guest.personId });
}

function openBoard(next) {
  for (const unsubscribe of subscriptions) unsubscribe();
  subscriptions = [];
  Object.assign(state, { board: next, drops: null, ideas: [] });
  cards.clear();
  ideaRows.clear();
  arrivals.clear();
  known = null;
  delete board.dataset.ready;
  liveEl.hidden = true;
  membersEl.replaceChildren();
  hideToast();
  const own = next !== SF_CREW;
  titleEl.textContent = own ? "your board" : "sf crew";
  ledeEl.textContent = own ? GUEST_LEDE : SF_CREW_LEDE;
  document.title = titleEl.textContent + " on resona";
  otherBoardEl.textContent = own ? "sf crew" : "try it";
  otherBoardEl.href = own ? "#" : "#try";
  addForm.hidden = !next?.personId;
  addNote.hidden = true;
  board.replaceChildren(text("p", "opening the board…", "quiet"));
  board.firstChild.id = "status";
  if (!next) return;
  subscriptions = [
    client.onUpdate(
      anyApi.drops.list,
      { boardId: next.id },
      (drops) => {
        announceNew(drops);
        state.drops = drops;
        update();
      },
      () => showStatus("the board didn't load. it'll try again in a moment."),
    ),
    client.onUpdate(
      anyApi.suggestions.list,
      { boardId: next.id },
      (ideas) => {
        state.ideas = ideas;
        update();
      },
      () => {},
    ),
  ];
}

addForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const value = addInput.value.trim();
  const personId = state.board?.personId;
  if (!value || !personId) return;
  if (ownCount() >= GUEST_LIMIT) {
    showNote("that's plenty for a test board.");
    return;
  }
  const link = value.match(/https?:\/\/\S+/)?.[0] ?? null;
  const note = (link ? value.replace(link, "") : value).trim() || null;
  addButton.disabled = true;
  try {
    await client.mutation(anyApi.drops.submit, {
      boardId: state.board.id,
      personId,
      clientId: crypto.randomUUID(),
      kind: link ? "url" : "text",
      url: link,
      text: note,
      capturedAt: Date.now(),
      utcOffsetMinutes: -new Date().getTimezoneOffset(),
    });
    addInput.value = "";
    addNote.hidden = true;
  } catch {
    showNote("that didn't save. try again.");
  } finally {
    addButton.disabled = false;
  }
});

async function makeGuest() {
  const personId = crypto.randomUUID();
  const person = await client.mutation(anyApi.people.upsert, { personId, personalBoardId: crypto.randomUUID(), name: "you" });
  const made = { personId, boardId: person.personalBoardId };
  try {
    localStorage.setItem(GUEST_KEY, JSON.stringify(made));
  } catch {
    return made;
  }
  return made;
}

function loadGuest() {
  try {
    const saved = JSON.parse(localStorage.getItem(GUEST_KEY) ?? "null");
    return saved?.personId && saved?.boardId ? saved : null;
  } catch {
    return null;
  }
}

function ownCount() {
  return (state.drops ?? []).filter((drop) => drop.authorId === state.board?.personId).length;
}

function showNote(message) {
  addNote.textContent = message;
  addNote.hidden = false;
}

for (const button of switchButtons) {
  button.addEventListener("click", () => {
    if (state.view === button.dataset.view) return;
    state.view = button.dataset.view;
    for (const other of switchButtons) other.setAttribute("aria-selected", String(other === button));
    update();
  });
}

toastEl.addEventListener("click", () => {
  const target = cards.get(toastEl.dataset.clientId)?.el;
  hideToast();
  target?.scrollIntoView({ behavior: reduceMotion.matches ? "auto" : "smooth", block: "center" });
});

function update() {
  if (!state.drops) return;
  const first = !board.dataset.ready;
  board.dataset.ready = "1";
  liveEl.hidden = false;
  if (first || reduceMotion.matches || !document.startViewTransition) {
    render();
  } else {
    document.startViewTransition(render).ready.catch(() => {});
  }
}

function render() {
  const sections = state.view === "mood" ? moodSections() : whenSections();
  const used = new Set();
  const nodes = sections.map((section) => sectionNode(section, used));
  if (nodes.length === 0) nodes.push(text("p", state.board?.personId ? "your board is empty for now." : "nothing's on this board yet.", "quiet"));
  board.replaceChildren(...nodes);
  for (const id of cards.keys()) if (!used.has(id)) cards.delete(id);
  renderMembers();
}

function moodSections() {
  const fresh = [];
  const rest = [];
  const clusters = new Map();
  for (const drop of liveDrops()) {
    if (drop.status === "pending") fresh.push(drop);
    else if (drop.clusterId) {
      if (!clusters.has(drop.clusterId)) clusters.set(drop.clusterId, { key: drop.clusterId, title: clean(drop.clusterLabel) ?? "a group", drops: [] });
      clusters.get(drop.clusterId).drops.push(drop);
    } else rest.push(drop);
  }
  const ideasByCluster = new Map(state.ideas.map((group) => [group.clusterId, group]));
  const groups = [...clusters.values()].sort((a, b) => b.drops.length - a.drops.length || a.title.localeCompare(b.title));
  for (const group of groups) group.ideas = ideasByCluster.get(group.key);
  return [{ key: "just-in", title: "just in", drops: fresh }, ...groups, { key: "rest", title: "everything else", drops: rest }].filter(
    (section) => section.drops.length > 0,
  );
}

function whenSections() {
  const buckets = new Map([["just-in", []], ...TIME_ORDER.map((zone) => [zone, []]), ["anytime", []]]);
  const now = Date.now();
  for (const drop of liveDrops()) {
    if (drop.status === "pending") buckets.get("just-in").push(drop);
    else buckets.get(timeZone(drop, now)).push(drop);
  }
  return [...buckets.entries()]
    .map(([key, drops]) => ({ key, title: key === "just-in" ? "just in" : TIME_LABELS[key], drops }))
    .filter((section) => section.drops.length > 0);
}

function liveDrops() {
  return state.drops.filter((drop) => drop.zone !== "done");
}

function timeZone(drop, now) {
  const stored = drop.zone;
  const storedRank = TIME_ORDER.indexOf(stored);
  if (storedRank < 0) return "anytime";
  if (drop.zoneSetByUser) return stored;
  const timed = zoneFor(drop.extraction?.dueAt ?? drop.extraction?.startsAt, now);
  const timedRank = TIME_ORDER.indexOf(timed);
  return timedRank >= 0 && timedRank < storedRank ? timed : stored;
}

function zoneFor(ms, now) {
  if (typeof ms !== "number") return null;
  if (ms - now <= 90 * 60 * 1000) return "now";
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const lateTonight = new Date(tomorrow);
  lateTonight.setHours(5);
  if (ms < tomorrow.getTime()) return new Date(ms).getHours() >= 17 ? "tonight" : "now";
  if (ms < lateTonight.getTime()) return "tonight";
  const monday = new Date(today);
  monday.setDate(monday.getDate() + ((8 - today.getDay()) % 7 || 7));
  const friday = new Date(monday);
  friday.setDate(friday.getDate() - 3);
  friday.setHours(17);
  if (ms >= friday.getTime() && ms < monday.getTime()) return "thisWeekend";
  return null;
}

function sectionNode(section, used) {
  const node = document.createElement("section");
  node.className = "group";
  node.style.viewTransitionName = "g-" + slug(section.key);
  const heading = text("h2", section.title + " ");
  heading.append(text("span", String(section.drops.length), "count"));
  const grid = document.createElement("div");
  grid.className = "grid";
  grid.replaceChildren(
    ...section.drops.map((drop) => {
      used.add(drop.clientId);
      return cardFor(drop);
    }),
  );
  node.append(heading, grid);
  if (section.ideas && (section.ideas.searching || section.ideas.suggestions.length > 0)) node.append(ideasNode(section.ideas));
  return node;
}

function cardFor(drop) {
  const face = dropFace(drop);
  const signature = JSON.stringify(face);
  const cached = cards.get(drop.clientId);
  if (cached && cached.signature === signature) return cached.el;

  const el = linkOrBlock(face.link, "card");
  el.style.viewTransitionName = "d-" + slug(drop.clientId);
  if (arrivals.delete(drop.clientId)) el.classList.add("arrived");

  const media = document.createElement("div");
  media.className = "media";
  if (face.thumb) {
    const img = image(face.thumb);
    img.addEventListener("error", () => {
      img.remove();
      media.classList.add("bare");
    });
    media.append(img);
  } else {
    media.classList.add("bare");
  }
  media.append(tag(face.kind, face.kindWord));

  const body = document.createElement("div");
  body.className = "body";
  body.append(text("h3", face.title));
  if (face.meta) body.append(text("p", face.meta, "meta"));
  if (face.line) body.append(text("p", face.line, "line"));
  const byline = text("p", "", "byline");
  byline.append(avatar(face.author, face.color), text("span", face.author, "name"));
  if (face.when) byline.append(text("time", face.when, "ago"));
  body.append(byline);

  el.append(media, body);
  cards.set(drop.clientId, { signature, el });
  return el;
}

function dropFace(drop) {
  const kind = kindOf(drop);
  const pending = drop.status === "pending";
  const title =
    clean(drop.title) ?? clean(drop.extraction?.title) ?? clean(drop.enrichment?.title) ?? clean(drop.text) ?? host(drop.url) ?? "something new";
  return {
    link: safeUrl(drop.url) ?? safeUrl(drop.imageUrls?.[0]),
    kind,
    kindWord: kind === "clip" && drop.enrichment?.durationSec ? "clip " + duration(drop.enrichment.durationSec) : kind,
    thumb: safeUrl(drop.thumbnailUrl ?? drop.imageUrls?.[0] ?? drop.enrichment?.thumbnailUrl),
    title,
    meta: pending ? "reading it now" : meta(drop, kind, title),
    line: pending ? null : clean(drop.suggestion),
    author: clean(drop.authorName) ?? "someone",
    color: PALETTE[drop.authorColor] ?? null,
    when: ago(drop.capturedAt),
  };
}

function kindOf(drop) {
  if (drop.extraction?.dueAt) return "reminder";
  if (drop.kind === "video" || clipSite(drop.url, Boolean(drop.enrichment?.durationSec))) return "clip";
  const type = drop.decision?.type;
  if (type === "song" || type === "event" || type === "place") return type;
  return { image: "photo", audio: "voice", url: "link", text: "note", pdf: "note" }[drop.kind] ?? "link";
}

function clipSite(link, hasLength) {
  let url;
  try {
    url = new URL(link);
  } catch {
    return null;
  }
  const hostname = url.hostname.toLowerCase();
  const site = CLIP_SITES.find(([domain]) => hostname === domain || hostname.endsWith("." + domain));
  if (!site) return null;
  if (site[1] === "instagram" && !hasLength && !url.pathname.startsWith("/reel") && !url.pathname.startsWith("/tv")) return null;
  return site[1];
}

function meta(drop, kind, title) {
  const place = clean(drop.extraction?.placeName) ?? clean(drop.extraction?.area);
  const site = clipSite(drop.url, true) ?? clean(drop.enrichment?.siteName) ?? host(drop.url);
  const parts = kind === "song" ? [clean(drop.enrichment?.author)] : kind === "event" ? [clean(drop.extraction?.whenLabel), place] : [place, site];
  return parts.find((part) => part && part !== title) ?? null;
}

function ideasNode(group) {
  const wrap = document.createElement("div");
  wrap.className = "ideas";
  wrap.append(text("h3", "suggestions for this group"));
  if (group.suggestions.length === 0) {
    wrap.append(text("p", "looking for some…", "quiet small"));
    return wrap;
  }
  const list = document.createElement("div");
  list.className = "idea-list";
  list.replaceChildren(...group.suggestions.map(ideaFor));
  wrap.append(list);
  return wrap;
}

function ideaFor(idea) {
  const signature = JSON.stringify(idea);
  const cached = ideaRows.get(idea.id);
  if (cached && cached.signature === signature) return cached.el;

  const el = linkOrBlock(safeUrl(idea.url), "idea");
  const thumb = document.createElement("div");
  thumb.className = "idea-thumb";
  thumb.innerHTML = icon(idea.kind);
  const src = safeUrl(idea.thumbnailUrl);
  if (src) {
    const img = image(src);
    img.addEventListener("error", () => img.remove());
    thumb.append(img);
  }
  const body = document.createElement("div");
  body.className = "idea-body";
  body.append(text("p", idea.kind === "watch" ? "to watch" : idea.kind, "idea-kind"), text("h4", clean(idea.title) ?? "a suggestion"));
  const details = ideaMeta(idea);
  if (details) body.append(text("p", details, "meta"));
  if (idea.reason) body.append(text("p", clean(idea.reason), "line"));
  el.append(thumb, body);
  ideaRows.set(idea.id, { signature, el });
  return el;
}

function ideaMeta(idea) {
  const price = typeof idea.price === "number" ? (idea.price === 0 ? "free" : "$" + Math.round(idea.price)) : null;
  const parts = idea.kind === "event" ? [idea.when, idea.where, price] : idea.kind === "place" ? [idea.where] : [idea.by];
  return parts.map(clean).filter(Boolean).join(" · ") || null;
}

function renderMembers() {
  const people = new Map();
  for (const drop of state.drops) {
    if (!drop.authorColor || !drop.authorName || people.has(drop.authorId)) continue;
    people.set(drop.authorId, { name: clean(drop.authorName), color: drop.authorColor });
  }
  const sorted = [...people.values()].sort((a, b) => PALETTE_ORDER.indexOf(a.color) - PALETTE_ORDER.indexOf(b.color));
  membersEl.replaceChildren(...sorted.map((person) => avatar(person.name, PALETTE[person.color], true)));
  membersEl.setAttribute("aria-label", sorted.map((person) => person.name).join(", "));
}

function announceNew(drops) {
  if (known) {
    const added = drops.filter((drop) => !known.has(drop.clientId));
    for (const drop of added) arrivals.add(drop.clientId);
    const fromSomeoneElse = added.find((drop) => drop.authorId !== state.board?.personId);
    if (fromSomeoneElse) showToast(fromSomeoneElse);
  }
  known = new Set(drops.map((drop) => drop.clientId));
}

function showToast(drop) {
  toastEl.dataset.clientId = drop.clientId;
  toastEl.textContent = (clean(drop.authorName) ?? "someone") + " just added something.";
  toastEl.hidden = false;
  requestAnimationFrame(() => toastEl.classList.add("shown"));
  clearTimeout(toastTimer);
  toastTimer = setTimeout(hideToast, 6000);
}

function hideToast() {
  toastEl.classList.remove("shown");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toastEl.hidden = true), 300);
}

function showStatus(message) {
  const status = document.getElementById("status");
  if (status && !board.dataset.ready) status.textContent = message;
}

function linkOrBlock(href, className) {
  const el = document.createElement(href ? "a" : "div");
  el.className = className;
  if (href) {
    el.href = href;
    el.target = "_blank";
    el.rel = "noopener";
  }
  return el;
}

function tag(kind, word) {
  const el = document.createElement("span");
  el.className = "tag";
  el.innerHTML = icon(kind);
  el.append(word);
  return el;
}

function avatar(name, color, large = false) {
  const el = text("span", (name ?? "?").trim().charAt(0).toUpperCase() || "?", large ? "avatar large" : "avatar");
  if (color) el.style.background = color;
  else el.classList.add("plain");
  el.setAttribute("aria-hidden", "true");
  return el;
}

function image(src) {
  const img = document.createElement("img");
  img.src = src;
  img.alt = "";
  img.loading = "lazy";
  img.decoding = "async";
  img.referrerPolicy = "no-referrer";
  return img;
}

function text(tagName, value, className) {
  const el = document.createElement(tagName);
  if (className) el.className = className;
  el.textContent = value;
  return el;
}

function clean(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed || null;
}

function safeUrl(value) {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    if (url.protocol === "http:") url.protocol = "https:";
    return url.protocol === "https:" ? url.href : null;
  } catch {
    return null;
  }
}

function host(value) {
  try {
    return new URL(value).hostname.replace(/^www\./, "");
  } catch {
    return null;
  }
}

function duration(seconds) {
  const total = Math.round(seconds);
  return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
}

function ago(ms) {
  if (typeof ms !== "number") return null;
  const minutes = Math.max(0, Math.round((Date.now() - ms) / 60000));
  if (minutes < 1) return "now";
  if (minutes < 60) return minutes + "m";
  const hours = Math.round(minutes / 60);
  if (hours < 24) return hours + "h";
  const days = Math.round(hours / 24);
  if (days < 7) return days + "d";
  return Math.round(days / 7) + "w";
}

function slug(value) {
  return String(value).replace(/[^a-zA-Z0-9_-]/g, "-");
}
