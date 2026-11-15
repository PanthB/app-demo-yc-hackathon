# SF demo plan

The demo board is one person's week of saving San Francisco: places, shows, songs and things to do. When the demo runs on Sunday night (November 15, 2026), "this weekend" means Saturday, November 21.

The story in one breath: *you saved a week of SF from TikTok, Instagram, Spotify and your camera roll, and the board sorted it by when and where you can act on it. On Valencia Street, the Mission saves come toward you.*

Every link below went through the backend's own link reader (`convex/lib/enrich.ts`) and the no-key rules (`convex/lib/rules.ts`) on November 15, with the drop saved at 6pm Pacific. The **lands in** column is where each one ended up. With `OPENROUTER_API_KEY` set, Clairic reads each drop and Jev places it, so a few placements may shift.

## Before the demo

1. **Keys.** Set `OPENROUTER_API_KEY` in the Convex environment for `adorable-coyote-696`. Without it, every drop still lands, but rules do the placing and no screenshot gets read. `SUPERMEMORY_API_KEY` is optional, and Pro is free for a month with the code `CAPYSM`.
2. **Fix the four reader problems below,** or leave out the drops they affect.
3. **Seed the board in the afternoon.** A drop's zone is worked out when it's saved, and "tonight" needs the time to be more than 3 hours away. Saved at 6pm, "tonight at 8" lands in **now**, while "tonight at 10" lands in **tonight**.
4. **Put the photos on the phone** (see Photos). On a cloud iPhone, download them into Photos first.
5. **Location.** Start away from the Mission so the board opens in planning mode. Then move to Valencia & 18th, with `demo/mission-walk.gpx` or by setting the location by hand (see Wandering).

## Reader problems found while checking links

| Problem | What happens | Fix |
| - | - | - |
| TikTok gives no caption | TikTok's oEmbed now returns only an iframe, with no `title`, `author_name` or `thumbnail_url`, and the page's og tags carry just `TikTok · <creator>` and a share-card image. Every TikTok lands as a vibes postcard named after its creator. | Get the caption from ScrapeCreators (see below). Without it, the reader gets only the share-card image when the OpenRouter key is on, so pick TikToks whose cover shows the place, or share a screenshot of the TikTok. |
| Instagram's post date is read as the plan's date | og:description reads `932 likes, 19 comments - user on March 18, 2026: "caption"`, and chrono picks up the date, so the Golden Gate post lands as an **event**, "march 18", in someday. The whole caption also ends up as the author. | In `enrichLink`, strip the `N likes, N comments - user on <date>:` prefix from the description, use the username as the author and the caption as the title. |
| Apple Music's song length is read as a time | "Duration 2:58" becomes "tomorrow at 2:58am", so the song lands in someday instead of vibes. | Leave the time out for music hosts, or ignore durations. Spotify links work fine, so the demo uses Spotify. |
| "in one hour" isn't a countdown | Only a digit counts (`/^in\s+\d/`). "remind me in one hour…" and "…in an hour…" land as an event stub with no countdown. Dictated voice notes usually come out as words. | Accept `an`, `a` and number words in the countdown check. Until then, type "in 1 hr". |

## Captions through ScrapeCreators

`SCRAPECREATORS_API_KEY` is in the Capy project environment, which agents' machines can use. It isn't in the Convex environment, so the backend can't use it yet. The account had 1,200 credits, and one test call on November 15 used one of them:

- `GET https://api.scrapecreators.com/v2/tiktok/video?url=<tiktok url>&trim=true` with an `x-api-key` header returned 200 for the Dolores Park TikTok below. `aweme_detail.desc` held the caption, "Dolores park on a sunny day ☀️ my favorite place to be #sanfrancisco #sanfranciscobayarea #sf #bayarea", along with the author, stats and `create_time`. That call cost 1 credit.
- With that caption as the title, the no-key rules place the TikTok as a **place** (park, sunny) **cutout in someday**. Without the caption, it's a vibes postcard named "grace :o".
- The cover that comes back is a 300×400 `.heic`, which Clairic doesn't accept, since it reads only png, jpeg and webp. Keep using the page's og:image (a jpeg share card) as the image, and take only the caption from ScrapeCreators.
- `/v1/instagram/post?url=…` returns the caption and the publish time (`created_at`) as separate fields, so it would also fix the Instagram date problem. It hasn't been tried yet.
- To spend fewer credits, add `cache_max_age=30d`, which returns a cached result for 0 credits, and never set `download_media`, which costs 10 credits.

## The drops

### Now and tonight (typed notes)

| Note | Lands in | When to add it |
| - | - | - |
| `remind me in 1 hr to grab a burrito at la taqueria on mission street` | now, countdown sticky, "in 1 hr" | **Live** in the demo |
| `drinks at zeitgeist on valencia tonight at 10` | tonight, stub, "tonight at 10pm" | Seed before 7pm |

### This weekend (Saturday, November 21)

| Drop | Link | Lands in |
| - | - | - |
| Poi Dog Pondering at The Chapel (777 Valencia, Mission), doors 8pm, $28–33 | <https://goseeshows.com/san-francisco/shows/2026-11-21-the-chapel-poi-dog-pondering/> | this weekend, stub |
| Secondhand Saturday vintage market, season finale (Sunset Mercantile, 37th Ave), 10am–4pm, free | <https://sf.funcheap.com/sfs-secondhand-saturday-2025-w-sunset-mercantile-season-finale/> | this weekend, stub, vintage and market |
| Typed: `dolores park picnic saturday, grab a tartine morning bun on the way` | none | this weekend, postcard |
| Bigger-name option: Jonas Brothers at Chase Center, 7:30pm | <https://goseeshows.com/san-francisco/shows/2026-11-21-chase-center-jonas-brothers/> | this weekend, stub |
| R&B and soul option: Q Marsden at The Independent, 9pm | <https://goseeshows.com/san-francisco/shows/2026-11-21-the-independent-q-marsden/> | this weekend, stub |

### Someday

| Drop | Link | Lands in |
| - | - | - |
| Stonemill Matcha (561 Valencia), the wandering target | <https://www.stonemillmatcha-us.com/> | someday, place, matcha |
| Marufuku Ramen (Japantown) video | <https://www.youtube.com/watch?v=zmIgc0SkVgE> | someday, place, ramen |
| Beach Bunny at The Fillmore, Saturday, March 13, 2027 (the brief's "concert, sometime in march") | <https://goseeshows.com/san-francisco/shows/2027-03-13-the-fillmore-beach-bunny/> | someday, event stub, "march 13" |
| Lands End trail (Sutro Baths, Pacific views) | <https://www.nps.gov/goga/planyourvisit/landsend.htm> | someday, place, park |
| Muir Woods, the California day trip | <https://www.nps.gov/muwo/planyourvisit/index.htm> | someday, place, park |
| Tartine morning bun, an **Instagram post** | <https://www.instagram.com/p/DHY65llvDPK/> | someday, place, bakery, but labeled "march 19" until the Instagram fix lands |

### Vibes

| Drop | Link | Lands in |
| - | - | - |
| Journey, "Lights", the SF anthem | <https://open.spotify.com/track/7EHmKkyAr6MZv5Y2FdZbXw> | vibes, record |
| Otis Redding, "(Sittin' On) the Dock of the Bay", written in Sausalito | <https://open.spotify.com/track/3zBhihYUHBmGd2bcQIobrF> | vibes, record |
| Fleetwood Mac, "Dreams" | <https://open.spotify.com/track/0ofHAoxe9vBkTCp2UQIavz> | vibes, record |
| Frank Ocean, "Pink + White", the golden-hour one | <https://open.spotify.com/track/3xKsf9qdS1CyvXSMEid6g8> | vibes, record |
| Kehlani, "Nights Like This", from Oakland | <https://open.spotify.com/track/6ZRuF2n1CQxyxxAAWsKJOy> | vibes, record |
| Beach Bunny, "Prom Queen", which pairs with the Fillmore show | <https://open.spotify.com/track/6MpCaSIOfqBqbMED4kXgNY> | vibes, record |
| TikTok: Dolores Park on a sunny day | <https://www.tiktok.com/@graacciiee/video/7617551860244745503> | vibes, postcard ("grace :o") |
| TikTok: 15 things to do in SF | <https://www.tiktok.com/@marissadaily_/video/7541446036347309343> | vibes, postcard |
| TikTok: Mission District food tour | <https://www.tiktok.com/@thesnacksensei/video/7561602082596343095> | vibes, postcard |
| **Instagram post:** the Golden Gate Bridge and Fort Point in morning light | <https://www.instagram.com/p/DWCN6pbgn3F/> | **event, "march 18", someday** until the Instagram fix lands, then vibes |
| **Instagram reel:** "the Golden Gate Bridge still feels unreal" | <https://www.instagram.com/reel/DbySW82ILGn/> | **event, "august 8", someday** until the fix lands |

### Photos and a screenshot

These are free-license photos from Wikimedia Commons. Download them into the phone's Photos and share them from there. They probably don't carry GPS, so each one is anchored to wherever the phone is when it's saved.

| Photo | Download | License |
| - | - | - |
| Golden Gate at sunset | <https://thumb.wikimedia.org/wikipedia/commons/thumb/5/57/Golden_Gate_Sunset._%28Unsplash%29.jpg/1920px-Golden_Gate_Sunset._%28Unsplash%29.jpg> | CC0 |
| Painted Ladies, Alamo Square | <https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f6/San_Francisco_%28CA%2C_USA%29%2C_Painted_Ladies_--_2022_--_3055.jpg/1920px-San_Francisco_%28CA%2C_USA%29%2C_Painted_Ladies_--_2022_--_3055.jpg> | CC BY-SA 4.0 |
| The skyline from Dolores Park | <https://thumb.wikimedia.org/wikipedia/commons/thumb/8/8f/San_Francisco_Skyline_-_Mission_Dolores_Park.jpg/1920px-San_Francisco_Skyline_-_Mission_Dolores_Park.jpg> | CC BY 2.0 |

**Screenshot to take live:** Marufuku Ramen's menu at <https://www.marufukuramen.com/>, or its Apple Maps card, with "chicken paitan" or the price showing. That's the brief's "a ramen screenshot becomes 'this, some weeknight'". It needs the OpenRouter key, because without one nothing reads an image.

## Connections to show

- **Beach Bunny:** the "Prom Queen" record and the Fillmore show share "beach" and "bunny", so they connect even on rules.
- **Saturday in the Mission:** the Dolores Park picnic note and the Tartine post share "tartine" and "bun", so they connect on rules once the Instagram fix lands. With Jev on, The Chapel show and Stonemill should join them, since they're all a few minutes apart on Valencia.

## Live script (about 3 minutes)

1. **Open on the board in planning mode.** "you saved a week of sf, and it's sorted by when you can actually do it." Point at tonight, this weekend, someday and vibes.
2. **Share "Prom Queen" from Spotify.** The share sheet shows "dropped it, i'll find it a spot". The record lands in vibes and pulses once, because it connects to the Beach Bunny show in March.
3. **Type the countdown:** `remind me in 1 hr to grab a burrito at la taqueria on mission street`. A sticky appears in now, counting down, with a real local notification behind it.
4. **Share the Marufuku screenshot** from Photos. With keys on, it's read as ramen in Japantown and lands as "some weeknight".
5. **Tap the Tartine object.** It flips to its tag: who dropped it, what was read and when.
6. **Drag Muir Woods from someday into this weekend.** The move sticks, because a zone the person sets is never overridden.
7. **Walk to Valencia & 18th.** The board switches to wandering, and the Mission saves come forward. Say "the matcha place you saved is 4 min that way."

Close with: "save it from anywhere and let it find you when you're close."

## Wandering

Straight-line distance from Valencia & 18th, with walking minutes padded by 25%:

| Spot | Coordinates | From Valencia & 18th |
| - | - | - |
| The Chapel, 777 Valencia | 37.76049, -122.42120 | ~2 min |
| Tartine Bakery, 600 Guerrero | 37.76146, -122.42395 | ~3 min |
| Stonemill Matcha, 561 Valencia | 37.76402, -122.42153 | ~4 min |
| Mission Dolores Park | 37.75972, -122.42713 | ~8 min |
| Zeitgeist, 199 Valencia | 37.77004, -122.42212 | ~15 min |
| La Taqueria, 2889 Mission | 37.75089, -122.41807 | ~19 min |

All six are within the 20-minute "nearby" cutoff in `convex/board.ts`. `demo/mission-walk.gpx` holds 40 seconds at the Ferry Building, so the board starts in planning mode, then jumps to Valencia & 16th and walks south to 18th. Use it in Xcode's Simulate Location, on a simulator or a tethered phone. APPD-3 can also copy it into `ios/Location` for the DEBUG GPX source.

## Our own Instagram post

> saved a week of san francisco into one board. a show at the chapel saturday, ramen for some weeknight, the record that goes with march, and the matcha place that's 4 min that way. save it from anywhere and let it find you when you're close.
>
> built today at the consumer mobile hackathon at yc, with capy, convex and revyl.

For the image, use a screen recording of the board switching to wandering on Valencia, or the Golden Gate sunset photo with the board on top.
