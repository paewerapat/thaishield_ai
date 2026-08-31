# ThaiShield AI — Project Blueprint & Developer Rules

> **Revision 2026-08-11.** This file is now the **single source of truth** for the
> Flutter app. `FLUTTER_INTEGRATION.md` has been merged into §3 below and should be
> deleted — do not keep two copies of the data contract.
>
> **What changed in this revision:**
> 1. Quotation **Phase 1 (Web Admin Dashboard) is complete, delivered and billed** — it
>    is no longer an active work phase. What survives from it is the data contract in §3.
> 2. The old **Phase 2 (Smart Map Premium V2)** has been split into **three smaller
>    delivery phases — 2A / 2B / 2C** — so that no single payment installment exceeds
>    **10,000 THB** (client bank/transfer limit). See §5.

You are an expert Flutter & Firebase developer helper. You are assisting a developer
working on a Windows/Linux environment (**NO LOCAL MAC MACHINE AVAILABLE**). Follow
these specifications strictly.

---

## 1. Environment & Architecture Constraints

- **Framework:** Pure Flutter (Stable channel).
- **Local Dev OS:** Windows/Linux. **NEVER** command the user to run Mac-specific steps
  locally (e.g. `pod install`, `open ios/Runner.xcworkspace`, `xcodebuild`).
- **Local Testing:** Target **Android physical devices** via USB debugging for features
  requiring Camera, Microphone (STT), GPS and billing sandbox.
- **iOS Strategy:** iOS builds are handled via Cloud CI/CD (Codemagic / GitHub Actions)
  in the final phase. Write portable, cross-platform Flutter code.
- **State Management:** Provider or Riverpod (business logic strictly decoupled from UI).
- **Architecture:** Feature-First. Folders under `lib/features/` (e.g.
  `lib/features/onboarding/`, `lib/features/scanner/`, `lib/features/map/`,
  `lib/features/sos/`, and for the new work `lib/features/radar/`,
  `lib/features/premium/`).

---

## 2. Delivered Baseline — งานที่ส่งมอบแล้ว (DO NOT RE-QUOTE, DO NOT REBUILD)

Everything in this section is **finished and paid for**. Treat it as the existing
codebase. Change it only when a task in §4 explicitly requires it, and run a regression
check (§4, Phase 2C) if you do.

| # | Feature | Status |
|---|---|---|
| B1 | **Language Onboarding** — first-launch language picker (TH, EN, ZH, KO, RU, JA), `shared_preferences` + `LocaleProvider`, ARB + `flutter_localizations`, 5-tab bottom nav (Home / Scan / Map / SOS / Profile), language switch from Profile, Android release signing + Play AAB upload | ✅ Complete |
| B2 | **Firebase Backend Setup** — `flutterfire configure`, `firebase_core` + `cloud_firestore`, `Firebase.initializeApp()` in `main.dart`, `FirestoreService` reading the three content collections | ✅ Complete |
| B3 | **Fair Price & Travel Alert Map v1** — `google_maps_flutter`, partner pins from `partner_locations`, custom pop-up (name, rating, verified badge), colored `alert_zones` overlays: green (safe) / amber (caution) / red (danger) | ✅ Complete |
| B4 | **Home Travel Alerts (newsdata.io)** — see §2.1 below | ✅ Complete |
| B5 | **AI Price Scanner** — see §2.2 below | ✅ Complete |
| B6 | **AI Voice SOS (STT → Gemini → Thai TTS)** — see §2.3 below | ✅ Complete |
| B7 | **Web CMS / Admin Dashboard** (separate repo, quotation Phase 1) — see §2.4 below | ✅ Delivered & deployed |

> ⚠️ **Seed data is obsolete.** "Populate Firestore via Firebase Console / seed scripts"
> is no longer the workflow. Content now comes from the CMS (B7). `tools/seed_firestore.js`
> and `lib/tools/seed_data.dart` still work against an **empty/local** project, but they
> are **not** the source of truth and **will overwrite staff edits if run against
> production**.

### 2.1 Home Travel Alerts (newsdata.io) — implementation notes

*(Moved off GNews on 2026-08-17. Nothing about the Firestore contract or the client
changed — only the function's source, query shape and field mapping.)*

- Shows Thailand travel-disruption news (floods, storms, fires, road closures, major
  accidents) on the Home tab and a full list screen, sourced from
  [newsdata.io](https://newsdata.io/documentation) (`/api/1/latest`).
- **Server-side shared cache — the Flutter app never calls the news API directly.** The
  scheduled Cloud Function `syncTravelAlerts` (`functions/index.js`, `asia-southeast1`)
  polls **every 10 minutes**, filters to Thai places plus a travel-disruption keyword, and
  upserts into `travel_alerts_cache` (doc id = newsdata.io's own `article_id`).
- **Why server-side:** `shared_preferences` is per-device. A client-side fetch means every
  install runs its own timer against the *same* API key, so volume scales with install
  count and blows the free tier. One server-side fetch keeps usage constant (24h × 6/hr =
  144 requests/day against an allowance of 200 credits) regardless of user count. 5-minute
  polling would be 288/day and blow it.
- ⚠️ **The free plan rejects any `q` over 100 characters** (`UnsupportedQueryLength`, HTTP
  422). The old GNews query was 183, so `QUERIES` holds two halves that alternate between
  runs, chosen from the clock — one request per run, each half on an effective 20-minute
  cadence. Adding a term means checking the length; a test enforces it.
- ⚠️ **`RUN_INTERVAL_MINUTES` drives both the schedule string and the rotation bucket.**
  Setting them apart silently desyncs the two: a 10-minute schedule read through a
  15-minute bucket yields A, A, B, A, so one query set runs twice as often as the other.
  A test asserts consecutive runs never repeat a query.
- ⚠️ **Do not use `country=th`.** It filters by the *source's* country, so it returns
  Bangkok Post's Kyiv and Hawaii wire copy while missing "Flash flood warning issued for 39
  Thai provinces" from an outlet registered elsewhere. The query is anchored on "Thailand"
  instead, and `THAI_PLACES` re-checks the text.
- ⚠️ **Judge location from title and description only, never `keywords`.** That field is
  the publisher's taxonomy — Bangkok Post tags most of its output "thailand", which put
  Kyiv and Hungary stories on the Home tab.
- Field mapping differs from GNews: `link`→`url`, `image_url`→`image`, `source_name`,
  and `pubDate` is `"YYYY-MM-DD HH:mm:ss"` in **UTC** — parse it with the `Z` appended or
  V8 reads it as local time and dates every article seven hours early.
- Pruning is **age-based**, not "anything this run did not return". With two rotating
  queries the latter would delete half the cache every 15 minutes.
- The app (`lib/features/home/services/travel_alert_service.dart`) does a plain Firestore
  read ordered by `published_at desc`.
- The key is **not** in the client — it is a Functions secret (`NEWSDATA_API_KEY`).
- Keep `SEARCH_TERMS` and `NON_EVENT_PHRASES` in `functions/index.js` in sync with the
  category keyword list and `_nonEventPhrases` in
  `lib/features/home/models/travel_alert.dart`.
- `cd functions && npm test` runs the filter's unit tests (node:test, no network).

### 2.2 AI Price Scanner — implementation notes

Two-stage matching from a native camera capture (`image_picker`):

1. **OCR first** (`google_mlkit_text_recognition`, on-device): reads printed text/numbers
   from menus or price tags, matches against `price_standards`, calculates variance %.
2. **Gemini Vision fallback**: if OCR finds no readable text or no matching item, the photo
   goes to Gemini (`lib/features/scanner/services/gemini_vision_service.dart`) to identify
   the dish name. GPS coordinates are passed **only** as disambiguation context for regional
   dish names — never stored, never used for location-specific pricing (`price_standards`
   has no location dimension). The identified name is looked up and shown as a **typical
   price range only** (no variance bar — no price was actually scanned).
3. **AI estimate** (added 2026-08-18): if the dish is not in `price_standards` at all, the
   same Vision call also returns a generic name and the model's own rough THB range, shown
   as a clearly-labelled estimate instead of the "no match" dead end this used to be.

- **Visual output:** colored variance bar (e.g. "+15% from standard price") for OCR
  matches; a plain typical-range card with an "AI Identified" badge for Vision matches;
  the same card with a grey **"ประมาณการโดย AI • ยังไม่ได้ตรวจสอบ" / "AI Estimate • Not
  Verified"** badge for stage 3.
- 🚨 **Stage 3 is a guess and must never be dressed as anything else.** `price_standards`
  ranges carry a staff member's judgement; these carry none. Therefore:
  - **Never** a variance bar or a percentage against an AI-estimated range — `ScanResult`
    keeps `detectedPrice` null, so `isReferenceOnly` already enforces this.
  - The synthetic `PriceStandard` behind it has an **empty `id`**. Nothing may look it up,
    cache it, or write it back to Firestore.
  - `confidence: low` responses are **discarded**, not shown with a caveat — a number a
    tourist might repeat to a vendor is worse than no number.
  - Copy follows §10 like everything else, and `test/dish_identification_test.dart` asserts
    both the six-language coverage and the absence of accusatory wording.
- There is **no** feedback loop writing unmatched dish names back to Firestore. That was
  considered and deliberately deferred: client writes are barred by §9, and it would need a
  Cloud Function.
- ⚠️ **Model version — verify before touching this code.** The scanner service was written
  against `gemini-2.5-flash`, but §2.3 records that all 2.x variants now return
  404 "not available to new users" for this API key and that `gemini-3.5-flash` is the
  confirmed working model. If the Vision path fails, this is the first thing to check —
  align both services on the same model string.
- 🚨 **CRITICAL LEGAL BOUNDARY:** the output UI **MUST NEVER** display specific restaurant
  names, exact locations, or brands — on **either** path. Statistical variance/range only.

### 2.3 AI Voice SOS — implementation notes

- Tap and hold to record → native STT → Gemini translation → Thai TTS playback.
- **Multi-language STT:** locale follows `LocaleProvider` — `en→en_US`, `zh→zh_CN`,
  `ko→ko_KR`, `ru→ru_RU`, `ja→ja_JP`, `th→th_TH`. The prompt is built as
  "The tourist said in [Language]: …" so Gemini always gets the correct source language.
- **PROMPT COMPLIANCE:** the returned Thai string MUST always end with a polite particle
  ("ครับ" / "ค่ะ").
- **Model:** `gemini-3.5-flash` via HTTP REST (`--dart-define=GEMINI_API_KEY`), endpoint
  `v1beta`. (`gemini-2.5-flash` and all 2.x variants return 404 "not available to new
  users" for this key — confirmed 2026-07.)
- **Emergency numbers** (`profile_screen.dart`): dial with `LaunchMode.externalApplication`
  to force the phone dialer — prevents extra digits or browser intercept on iOS/Android.

### 2.4 Web CMS / Admin Dashboard (quotation Phase 1 — CLOSED)

A separate web app, in a **different repository**, letting non-technical staff manage
Firestore content without the Firebase Console.

| | |
|---|---|
| Stack | Next.js 14 + Firebase Admin SDK (Server Actions) |
| Deploy target | **Firebase App Hosting** (not plain Firebase Hosting — it cannot run Server Actions, and its `webframeworks` support is legacy) |
| CMS URL | `https://thaishield-admin--thaishield-ai-790eb.asia-southeast1.hosted.app` |
| **Privacy policy URL** | `https://thaishield-admin--thaishield-ai-790eb.asia-southeast1.hosted.app/privacy` |
| Staff auth | Google Sign-In with domain restriction, Firebase Auth — **CMS only** |
| Manages | `price_standards`, `partner_locations` (with real photo upload to Firebase Storage), `alert_zones` (interactive Google Maps polygon editor) |

- 🚨 **The privacy policy URL is needed in three places and they must stay in step:**
  the Play Console listing, the App Store Connect listing, and **inside the app** —
  `_privacyPolicyUrl` in `profile_screen.dart`, shown as a row in Profile. This app
  asks for location, camera and microphone, and Play requires the policy to be
  reachable for that; a URL in the store listing is not the same as the user being
  able to open it. The page lives outside `/admin` on purpose (auth is enforced in
  `app/admin/layout.tsx`), so it needs no login.
- The web CMS **deploys from a push to `main`** — App Hosting builds from GitHub,
  live in about three minutes. There is no CLI deploy step for it, and
  `firebase login` has nothing to do with it; that is only for Cloud Functions.
  `WEB_ADMIN.md` §10.3 in the other repo is the authority.
- Staff auth in the CMS **does not contradict** §7 "no Firebase Auth in the app" — that
  rule is about the Flutter app, which still reads anonymously.
- The CMS writes through the **Admin SDK**, which bypasses Firestore rules entirely.
- Known open items on the CMS side (tracked in that repo's `STATUS.md`, **not blocking**
  Flutter work): partner photo upload never yet observed to succeed end-to-end, and a
  hands-on pass over the polygon editor.

---

## 3. Firestore Data Contract — READ THIS BEFORE WRITING ANY READ LAYER

*(Merged from the former `FLUTTER_INTEGRATION.md`. These shapes were read off the CMS's
actual write path — `lib/actions/*.ts`, `lib/schemas/*.ts` in the web-admin repo — not off
a spec. Where anything else disagrees, **this section is what is really in Firestore**.)*

| | |
|---|---|
| Firebase project | `thaishield-ai-790eb` |
| Region (Firestore, Storage, Functions, CMS backend) | `asia-southeast1` |
| Firestore rules | public read, **no client writes** (see §9) |
| App auth | none — the app reads anonymously |

### `price_standards`

```
id          string    // == document ID. lowercase / digits / underscore only
name_en     string
name_th     string
name_zh     string
name_ko     string
name_ru     string
name_ja     string
min_price   number     // THB
max_price   number     // THB
category    string     // "food" | "transport" | "attraction"
updated_at  timestamp  // server timestamp, rewritten on every save
```

The document ID **equals** the `id` field — the CMS writes with `.doc(parsed.id).set(…)`,
so a dish can be addressed directly by id (`pad_thai`) instead of querying.

### `partner_locations`

```
id           string    // == document ID
name         string    // the canonical name, always present
name_th      string    // optional official name — "" is the normal case
name_zh      string
name_ko      string
name_ru      string
name_ja      string
lat          number
lng          number
type         string    // one of the 11 categories below
rating       number    // 0.0–5.0
is_verified  bool
price_tier   string    // "fair" | "caution" | "high"
image_url    string    // may be "" — see below
```

- ⚠️ **No `updated_at` on this collection.** `price_standards` has one; this does not.
  Don't write a shared "last updated" widget that assumes the field exists.

#### The 11 `type` values (shipped 2026-08-11, Phase 2A task 2.3)

| value | Radar group | note |
|---|---|---|
| `restaurant` | Partner Businesses | original value |
| `hotel` | Partner Businesses | original value |
| `transport` | Transport | original value |
| `hospital` | Emergency Services | |
| `pharmacy` | Emergency Services | |
| `police` | Emergency Services | |
| `tourist_police` | Emergency Services | |
| `atm_bank` | Partner Businesses | |
| `shopping` | Partner Businesses | |
| `attraction` | Partner Businesses | |
| `tourist_info` | Partner Businesses | |

- The **first three keep their original strings**, so existing documents stayed valid and
  no data migration was needed.
- The list lives in **three places that must always change together**:
  `lib/core/models/partner_category.dart` (this repo, the `PartnerCategory` enum),
  `lib/schemas/partner-locations.ts` **and its tests** in the web-admin repo. A value
  staff can enter but the app can't render — or the reverse — is exactly what this
  pairing prevents. The seed scripts (`tools/seed_firestore.js`, `lib/tools/seed_data.dart`)
  carry one sample row per new value.
- Unknown/legacy `type` strings fall back to `restaurant` (`PartnerCategory.fromValue`),
  so a stray value degrades instead of crashing.
- Display names for all 11, in all 6 languages, are `cat_<value>` keys in
  `lib/core/localization/app_text.dart`.

### `alert_zones`

```
id              string
name            string           // the canonical name, always present
name_th         string           // optional official name — "" is the normal case
name_zh         string
name_ko         string
name_ru         string
name_ja         string
risk_level      string           // "safe" | "caution" | "danger"
description_en  string           // all six are REQUIRED in the CMS
description_th  string
description_zh  string
description_ko  string
description_ru  string
description_ja  string
polygon         array<GeoPoint>  // ← GeoPoint, NOT {lat,lng} maps
center_lat      number           // derived
center_lng      number           // derived
radius_km       number           // derived
```

- ⚠️ **`polygon` is an array of Firestore `GeoPoint`**, which deserializes in Dart to
  `List<GeoPoint>` — read `p.latitude` / `p.longitude`:

  ```dart
  final polygon = (data['polygon'] as List<dynamic>)
      .cast<GeoPoint>()
      .map((p) => LatLng(p.latitude, p.longitude))
      .toList();
  ```

- `center_lat`, `center_lng`, `radius_km` are **derived** — the CMS computes the centroid
  and bounding radius from the polygon on every save and stores them alongside it. Treat
  them as read-only convenience values: draw the overlay from `polygon`, and use
  `center_*` / `radius_km` only for cheap proximity pre-checks (e.g. deciding whether a
  zone is near the user before drawing it). **Phase 2A task 2.2 depends on exactly this.**

### `travel_alerts_cache` (written only by `syncTravelAlerts`)

```
id            string     // md5 of the article url == doc id, for idempotent upserts
title         string
description   string
url           string
image         string | null
source_name   string
published_at  timestamp
fetched_at    timestamp  // server timestamp of the sync run that wrote/refreshed this doc
```

The CMS neither reads nor writes this collection.

### `entitlements` (written by the app — added 2026-08-22)

```
<doc id>      string     // the store's own transaction id: Play purchaseToken,
                         // StoreKit originalTransactionId. Not a user id — the
                         // app has no identity to file this under (§7).
product_id    string     // thaishield_premium_weekly | thaishield_premium_monthly
expires_at    timestamp  // when the pass runs out
platform      string     // label only, for support; entitlements never cross platforms
recorded_at   timestamp  // serverTimestamp, so a wrong device clock cannot backdate it
```

🚨 **This collection is now obsolete and 2.8 should retire it.** It was built because the
products were one-time consumables, which neither store replays with their remaining days
on a new device — so "Restore Purchases" had nothing to restore. Since 2026-08-30 both
products are auto-renewing subscriptions, and both stores answer that question themselves.

Nothing reads it at runtime yet, so it is being left in place rather than deleted in the
same change that flipped the billing model. Task 2.8 should stop writing to it and drop
`create` to `if false` in §9. **Do not build anything new on it**, and do not treat a
document here as proof of payment — it never was one.

Read `lib/features/premium/services/entitlement_repository.dart` before touching it, and
§9 for why the rules look the way they do. The CMS neither reads nor writes this
collection.

### Partner images — the part most likely to surprise you

`image_url` used to be a hotlinked Pexels URL. It is now a **Firebase Storage download URL
with an access token**:

```
https://firebasestorage.googleapis.com/v0/b/<bucket>/o/partner_locations%2F<id>%2F<uuid>.jpg?alt=media&token=<uuid>
```

- It is still just an HTTPS URL. `Image.network` / `CachedNetworkImage` work unchanged, and
  **no Firebase Storage SDK is needed** in the app.
- These URLs **bypass Storage security rules** and need no authentication — by design,
  since the app has no auth and shows these to anonymous tourists.
- The token does not expire. A URL stops working only if someone revokes it from the
  Firebase Console, which is the intended way to pull a photo.
- **`image_url` can be an empty string** — the schema explicitly allows `""`. Keep the icon
  fallback in `_PartnerThumbnail` (`map_screen.dart`) rather than assuming a URL exists.
- Do **not** hardcode the `storage.googleapis.com/...` form. An earlier CMS build produced
  those; they cannot work, because the bucket uses uniform bucket-level access and the org
  enforces public-access prevention. Any such URL still in the data is stale.

### Things the CMS relies on — don't break them

- **Firestore rules stay public-read / no-client-write.** Never widen client rules to make
  something in the app work; that would let any install write to the documents staff
  maintain.
- **Document IDs match `^[a-z0-9_]+$`** and are immutable after creation in the CMS. If the
  app ever generates documents, follow the same convention.
- **§10 wording rules apply to CMS-entered text too.** `alert_zones` descriptions run through
  an automated linter in the CMS, but it only recognises **English** terms — **Thai copy is
  unchecked** and still needs human review. Anything the app displays verbatim from
  `description_th` carries that risk.

---

## 4. Remaining Scope — Smart Map Premium V2 (Option A, In-App Purchase)

Split into **three delivery phases**. Each ends in a demo-able build, which is what
triggers the corresponding invoice in §5.

### ✅ `feature-design.jpg` — settled 2026-08-22

**The client confirmed the poster is a mockup, not a specification.** Scope stays as
`Requirement.html`. They approved dropping ดัชนีความปลอดภัย, Smart Alerts, Offline Map and
AI Local Insights outright; they asked for the Radar to move into the Map screen and for a
**3-day** trial (down from 7), both given free; and they left Google Places search, the
category photo cards, and news-as-map-pins out of this phase. **Google Places being left
out means the "search finds nothing" complaint survives into release** — that was the
client's own call and is recorded in the Rev.4 quotation doc.

The analysis below is kept because it is why those four features were dropped. Do not
re-open them.

#### Item (ข) — the Radar moved onto the Map (done 2026-08-23, no charge)

`lib/features/map/widgets/around_you_panel.dart` — a draggable sheet on the Smart Map
showing the four area/partner counts, the nearby advisories, and the nearest partners with
distances in metres. Points to know before changing it:

- **It is not a second data path.** It renders a `RadarResult` from the same
  `RadarService` in-memory cache the pins are built from, recomputed locally on every
  position or filter change. That costs no Firestore reads, and it is why the sheet can
  never contradict the map behind it — including the Filter panel, which both obey.
- **Counts are never gated, list entries are.** The free tier sees every count and the
  nearest `freeRadarResultLimit` of *each* list, so a user beside four advisories still
  sees partners instead of having advisories eat the whole allowance. Hiding the counts
  would make the Map look broken rather than limited.
- **Only non-safe zones are listed as advisories**, though all of them are counted.
- `AroundYouPanel.minChildSize` and `_MapScreenState._aroundCollapsedFraction` are two
  literals that must stay equal, or the map's floating buttons end up behind the collapsed
  sheet. Both sides say so.
- The sheet is hidden while a pin or zone popup is open, so there is only ever one detail
  surface on screen.

Items (ก) Google Places search, (ค) category cards with photos and (จ) news as map pins
remain **not built** at the client's request.

### ⚠️ `feature-design.jpg` — the original analysis (received 2026-08-19)

`C:\Fastwork\thaishield-ai\feature-design.jpg` is a **one-page design/marketing poster**
for the Smart Map. It arrived **after** the quotation (`Requirement.html`, 29/07/2026) and
is **not** part of it. Read it before touching the Map, but do not treat it as the agreed
scope — much of it is new work, and two items conflict with rules this file sets.

The client's own summary of V2: *"ไม่ได้ต้องการเพิ่มฟีเจอร์ใหม่ แต่เป็นการพัฒนาและปรับปรุง
Smart Map ที่มีอยู่เดิมให้สามารถใช้งานได้จริง"* — open the Map, locate the user, show what
is within ~1 km, and make search actually find places. That framing matters: the three
things they asked for in prose are **fixes**, while the poster around them is not.

| | Item | Status |
|---|---|---|
| ✅ | Locate the user when the Map opens · blue dot · 1 km ring | **Done 2026-08-20** — see below |
| ✅ | Prices ฿99 / ฿799 / ฿1,999 | **Superseded 2026-08-22.** The client replaced the whole plan set with two USD passes — see "The plans changed on 2026-08-22". Do not use these figures |
| ✅ | "รอบตัวคุณในระยะ 1 กม." data (safe / caution / alert / partners) | Already built — **Safety Radar, 2A task 2.1**, default radius 1 km. The poster puts it *inside* the Map screen; ours is a separate screen off the Home tab |
| ⏳ | **Place search that works** | Current search is `geocoding.locationFromAddress` — an *address* geocoder, so POI names (malls, restaurants, attractions) frequently miss. Needs **Google Places** (Autocomplete + Details), a new paid API. **Approved 2026-08-30, not started, still not quoted.** Until it lands, "search finds nothing" ships |
| ✅ | **"คุณอยู่ที่นี่" address panel, count tiles, nearby lists** | **Built 2026-08-29, not charged.** The panel carries the reverse-geocoded area name, the zone the user is standing in, when the counts were taken, and "view all" into the Radar — see `around_you_panel.dart`. An unmapped spot says its information is missing, in grey, never in green (§10) |
| ⏳ | **Category icon row · category cards with photos** | Approved 2026-08-30, **not started**. UI assembly on data that mostly exists; the photo cards also need a new image field in the CMS. Still **not quoted** |
| ✅ | **Free trial** | **Built 2026-08-22, as 3 days rather than 7**, granted in-app because a store trial only attaches to a subscription and the products were one-time passes at the time. Since 2026-08-30 they are subscriptions again, so task 2.8 should move this to a store introductory offer and retire `PremiumProvider.startTrialIfEligible` — it survives meanwhile because a build with no billing has no other way to reach the paid state |
| 🚨 | **ดัชนีความปลอดภัย 95/100** | **Conflicts with §10.** Scoring an area is precisely the judgement the wording rules exist to prevent, and no data in this project can compute it. The four count tiles beside it already convey "what is around you" without rating anywhere |
| 🚨 | **Smart Alerts** (alerts fired by location) | **Conflicts with §7** — no background/geofencing notifications. 2A task 2.2 was agreed as foreground, on-open only |
| 🚨 | **Offline Map** | Google Maps SDK terms forbid caching tiles. Real offline maps mean replacing the map engine (Mapbox / MapLibre) — a rewrite of every map surface in the app |
| 🚨 | **AI Local Insights** | A new AI feature, never quoted, and high §10 exposure — an AI writing prose about an area is the hardest possible case for neutral wording |

**Before building anything else from the poster, settle whether it is a specification or a
brochure.** The phone mockup on the left is one screen; the panels around it read as a
feature list, not as UI. Interpreting the whole page as literal Map content changes the
size of this project.

### What the V2 fixes changed on the Map (2026-08-20)

- **The Map opens on the user.** It used to open on a fixed Bangkok coordinate at zoom 12
  regardless of where anyone was, with no blue dot at all (`myLocationEnabled` was never
  set) — the single biggest reason it felt like a picture instead of a tool.
  `_autoLocate()` runs **once**, on the first activation of the Map tab.
- ⚠️ **Not in `initState`.** `IndexedStack` builds every tab at launch, so locating there
  would ask for location permission before the user has opened anything — the same trap
  §2A documents for the Home proximity card.
- A pending `MapFocusRequest` (from the Radar's "Show on Map") **wins over auto-locate**:
  the position is still fetched, for the dot and the ring, but the camera is left alone.
- The **1 km ring** is drawn from `RadarService.defaultRadiusKm`, not a literal, so the
  circle on the map and the radius the Radar actually searches cannot drift apart. It is
  held outside `_circles`, which `_loadMapData` rebuilds from Firestore on every refresh.
- `_centerOnUser` now goes through `LocationService` like everything else; the last raw
  `Geolocator` call in `map_screen.dart` is gone.

### Phase 2A — Safety Radar & Filter (9,000 THB of work) — ✅ code complete 2026-08-11, pending device QA

| Task | Description | Est. | Status |
|---|---|---|---|
| 2.1 | **Safety Radar core** — "What's Around Me" on-demand radius search, returning cards for Safe Area / Advisory / Alert Zone / Verified Partners / Emergency Services / Transport | 1 week | ✅ `lib/features/radar/` |
| 2.2 | **Alert Zone proximity card** — foreground, on-open check; reuses the existing `alert_zones` polygon data (use `center_*` + `radius_km` for the cheap pre-check, `polygon` for the precise test) | 2–3 days | ✅ on the Home tab |
| 2.3 | **Filter panel UI** + `partner_locations.type` schema expansion (**3 → 11 categories**) + seed data update | 3–4 days | ✅ shared by Radar + Map |

**What 2A actually added**

- `lib/features/radar/` — `RadarService` (radius search + `zoneAtOrNear`), `RadarScreen`
  ("What's Around Me"), the shared **Filter panel**, radar cards, and the **Alert Zone
  proximity card**.
- `lib/core/utils/geo_utils.dart` — haversine `distanceKm`, ray-casting
  `isPointInPolygon`, and `isInsideZone`, which does the cheap `center_*`/`radius_km`
  rejection before the precise polygon test, exactly as §3 prescribes.
- `lib/core/services/location_service.dart` — one foreground location helper.
  `currentIfPermitted()` never raises the OS permission prompt and is what the Home-tab
  proximity card uses, so first launch is not hijacked by a permission dialog. There is no
  stream/background mode anywhere in this code (§7).
- `lib/core/models/partner_category.dart` — the 11-value enum + icon/colour/marker-hue
  tables and the Radar grouping.
- The Radar entry point is a **tool tile on the Home tab**, not a 6th bottom-nav tab —
  the nav bar stays at 5 items (§11).
- **The Map's "Layers" sheet was replaced by the shared Filter panel.** The old sheet had
  one "Partner Pins" switch, which can't express 11 categories. The panel is a strict
  superset: per-category pin filtering plus the same three zone-risk toggles. The map's
  second floating button is now `tune` with a count badge, so a narrowed map is never
  mistaken for missing data.
- Partner markers are now coloured **by category** (`partnerCategoryMarkerHue`) instead of
  by `is_verified`; verified status still shows as the "Certified Fair Price" badge in the
  partner panel and on radar cards.
- `_scanCategoryToPartnerType` in `home_screen.dart` no longer maps a scanned
  `attraction` onto `hotel` — `attraction` is a real category now.

**Definition of done (2A):**
- ✅ Radar returns results within the selected radius from `partner_locations` +
  `alert_zones` with no extra Firestore collections and no client writes. Both collections
  are fetched whole and cached in memory for 10 minutes, so changing the radius or the
  filters re-runs the maths locally instead of re-reading Firestore.
- ✅ The 11 category values are written down in this file (§3) and were applied in the same
  change to (a) the Flutter model/filter UI, (b) `lib/schemas/partner-locations.ts` in the
  web-admin repo, (c) that repo's schema tests (95 passing), (d) both seed scripts.
- ✅ Radar/proximity copy passes the §10 wording rules — every new string is neutral and
  statistical, the Radar carries the mandatory disclaimer as a permanent footer, and the
  proximity card carries the short form of it.
- ✅ `flutter analyze lib/` clean.
- ⏳ **Still owed: hands-on QA on an Android physical device** (location permission flow,
  radius/filter round-trips, "Show on Map" hand-off, no regression on the Map screen).
  This is the last gate before the งวดที่ 2 invoice.

### Phase 2B — Route Suggestion & Paywall UI (6,000 THB of work)

| Task | Description | Est. | Status |
|---|---|---|---|
| 2.4 | **Route Suggestion** — Google Directions API integration, route preview UI, travel-mode toggle, "Open in Google Maps" deep link | 1 week | ✅ code complete 2026-08-19, pending device QA — `lib/features/route/` |
| 2.5 | **Paywall / plan-comparison screen** + client-side feature gating for Radar details, Filter and Route Suggestion | 3–4 days | ✅ code complete 2026-08-19; **rebuilt for the new packages 2026-08-22** — see below |

**🚨 The plans changed again on 2026-08-30 — read this before touching
`lib/features/premium/` or either store console.**

There are now **two auto-renewing subscriptions in USD**:
`thaishield_premium_weekly` ($3.50, 7 days) and `thaishield_premium_monthly`
($10, 30 days). Create both in Play Console and App Store Connect as
**auto-renewing subscriptions**.

🚨 **A product's type cannot be changed after it is created, only replaced under
a new id.** This block has now been rewritten twice, and the previous rewrite
left the old instruction in place — the QA gate caught it on 2026-08-23 and
filed it critical, because following the stale half burns an id permanently.
**If any earlier text in this file tells you to create consumables, it is wrong
and should be deleted, not obeyed.**

`thaishield_premium_2weeks` is retired and must never be created. Nothing was
created in either console before this change (product creation is gated on the
banking profile, which is still outstanding), so no id was burned.

**Why the 14-day pass became weekly.** Neither store sells a 14-day billing
period — the choices are 1 week, 1 month, 2, 3, 6 months and a year — and that
gap is the whole reason the original design used one-time passes. Asked on
2026-08-30 to make both plans cancellable, the client chose to move the short
plan to weekly rather than run two billing models on one screen.

⚠️ **Auto-renewal is a poor fit for this audience, and that was put to the
client before they chose it.** A tourist who visits for a fortnight and flies
home keeps being charged until they remember to cancel, which becomes refund
requests and one-star reviews. It was their call. What the code owes them is
copy that states the renewal plainly rather than burying it — `premium_legal_note`
now names the renewal, the charge, where to cancel, and that access runs to the
end of the paid period.

Three things follow from subscriptions, each the reverse of what the consumable
design needed:

- **The store owns the clock.** A subscription reports its own renewal state.
  `Entitlement` records what the store said; it must not compute an end date
  from `PremiumPlan.duration`, which now only describes what the plan sells. A
  subscription can be cancelled, refunded, paused or lapse on a failed payment,
  and none of those are visible from a duration.
- **The store can own the trial.** A store-run free trial attaches to a
  subscription, so 2.8 should move the 3-day trial to a store introductory
  offer and retire `PremiumProvider.startTrialIfEligible`, which exists because
  a consumable could not carry one. Until billing is wired it is the only trial
  a build has, so do not delete it before its replacement works.
  - 🚨 **That move rewrites `premium_trial_note` in all six languages, in the
    same commit.** The current copy says the trial ends and the app returns to
    the free version by itself, and that billing starts only if the user picks
    a plan and confirms — true of an in-app trial, and the exact opposite of a
    store introductory offer, which converts into a paid subscription unless
    the user cancels first. Shipping the mechanism without the copy tells every
    user in their own language that they will not be charged, immediately
    before charging them. `wording_test.dart` fails the moment
    `startTrialIfEligible` disappears while that wording survives; the terms
    page (`app/terms/page.tsx` §4 in the web admin) says the same thing twice
    more and has no test at all.
- **Restore is the store's job on both platforms.** This is the one clear gain:
  StoreKit refused to replay consumables, which is why iOS restore was accepted
  as broken on 2026-08-23. Subscriptions restore on iOS and Android alike, so
  that limitation is gone and `premium_platform_note` no longer claims it.

🚨 **The `entitlements` Firestore collection (§3, §9) exists only because
consumables were not replayable.** With subscriptions the store answers the
question it was built to answer. Task 2.8 should stop writing to it and drop
`create` to `if false` rather than leaving a half-used collection that looks
like proof of payment. It is not being deleted in this change because nothing
reads it yet at runtime and removing storage is not something to do in the same
commit as changing a billing model.

⚠️ Once billing is live the figure **shown** must come from
`ProductDetails.price` — the store's own localised, tax-inclusive string —
never from `PremiumPlan.priceUsd`, which cannot follow a currency, a regional
tax rule, or a price change. `premium_price_note` already tells the user that
the store's price is the one they pay.

**What 2.4 actually added**

- `lib/features/route/` — `RouteService` (the API call, the cache and the response
  parser), `RoutePreviewScreen` (map + polyline + travel-mode toggle + summary card),
  `TravelMode`, `RouteSuggestion`, and `maps_deep_link.dart`.
- `lib/core/utils/polyline.dart` — the decoder for Google's encoded-polyline format, and
  `boundsFor` in `geo_utils.dart` to frame the drawn route.
- **Entry point:** a green "Directions" button beside "Show on Map" in the Map's partner
  detail sheet, which pushes `RoutePreviewScreen` over the whole app (so the route keeps
  its own header and the bottom nav does not sit on top of the summary card).
  `_openRoutePreview` in `map_screen.dart` is the single place the preview is opened
  from — **that is where task 2.5's paywall check goes.**
- Three travel modes: **Drive / Transit / Walk**. `TWO_WHEELER` is deliberately absent
  even though motorbikes matter here: the Routes API accepts it but the Google Maps deep
  link has no equivalent and silently downgrades to driving, so the preview and the
  hand-off would disagree with no error anywhere.
- The screen is a **preview, not a navigator** — no live re-routing and no background
  location (§7). Turn-by-turn is handed to Google Maps.

🚨 **The legacy Directions API is closed to new customers — this uses the Routes API.**
`maps.googleapis.com/maps/api/directions` cannot be enabled on a Cloud project that did
not already have it, so `RouteService` calls `routes.googleapis.com/directions/v2:computeRoutes`
(POST, `X-Goog-Api-Key` + `X-Goog-FieldMask`) instead. Same feature and the same billing
account; only the endpoint differs. This is the identical trap §2.2 records for the Gemini
2.x models — if routes fail with a 403/404 mentioning the API not being enabled, enable
**Routes API**, not Directions.

⚠️ **Cost.** Routes bills per request. Two guards, both of which must survive any edit:
`X-Goog-FieldMask` is held to the three fields the preview draws (widening it, or using
`*`, moves the call to a pricier SKU for data nothing renders), and `RouteService` caches
each (origin, destination, mode) answer for 5 minutes with the origin rounded to ~11 m, so
flipping the travel-mode toggle costs one request per mode rather than one per tap. Set a
daily quota cap in Cloud Console before the first release build.

**What 2.5 actually added**

- `lib/features/premium/` — `PremiumProvider` (**the single source of `isPremium`**),
  `Entitlement` + `EntitlementStore` (the local cache), `PremiumPlan`, `PremiumFeature`,
  `PaywallScreen`, `ensurePremium()` and the Radar upsell card.
- **Three gates, all reading the same provider:** `ensurePremium(context, feature)` in
  `map_screen._openFilterPanel`, `map_screen._openRoutePreview` and
  `radar_screen._openFilters`; plus the Radar list, which the free tier sees trimmed to
  `PremiumProvider.freeRadarResultLimit` (3) nearest results followed by a card naming how
  many were withheld. Each locked control draws a **padlock** rather than its normal icon,
  so nobody meets the paywall by surprise.
- **Profile** gained a status card — the app's only view of an entitlement, there being no
  account screen — and, in debug builds only, the **QA unlock switch**.
- Free tier keeps everything shipped before 2A/2B: map, pins, zones, Scanner, SOS, news,
  and the Radar itself.

**How this works with no user system.** It does not need one, and §7 still stands — no
Firebase Auth, no accounts, no login. Google Play and the App Store already hold the
identity: a purchase attaches to the **Google account / Apple ID**, not to the handset. So
2C's launch sequence is `restore()` → the store reports what that account owns → write it
to `EntitlementStore` → `notifyListeners()`. Reinstalling or signing in on a new phone
recovers access by itself.
⚠️ **Entitlements do not cross between Android and iOS** — a user who buys on Android and
switches to iPhone must buy again. Nothing short of real accounts changes that, so the
paywall states it, and `premium_platform_note` has a test pinning it in all six languages.

🚨 **`EntitlementStore` (shared_preferences) is a cache, never proof of purchase.** It
exists so a paying user is not shown a paywall while the store SDK starts up, and it is
per-device and per-install. 2C **must** re-verify against the store on every launch and
overwrite it — a cancelled subscription read only from disk would grant access forever.

**What 2C inherits.** `PremiumProvider.purchase()` and `.restore()` are the only stubs;
both return `StoreOutcome.notAvailableYet` today and the paywall already handles every
value of that enum. Task 2.8 replaces those two method bodies and adds a store-driven
refresh. **No screen changes.**

🚨 **Prices, product ids and product types moved again on 2026-08-30 — the only correct
copy of them is the block above** ("The plans changed again on 2026-08-30"). Two
**auto-renewing subscriptions**, both USD: `thaishield_premium_weekly` and
`thaishield_premium_monthly`. The `_2weeks`, `_yearly` and `_lifetime` ids are cancelled
and must never be created.

This paragraph has now been wrong twice, in the same way, and that is worth keeping on the
page. It first carried the ฿99 / ฿799 / ฿1,999 figures and told whoever set up the store to
create subscriptions; the 2026-08-22 rewrite left it behind and the QA gate caught it on
2026-08-23, filed critical. It then said consumables, and was stale again within eight days
when the model flipped back. **A product's type is irreversible in both stores** — an id
created from a stale paragraph is burned, and recovering it costs a fresh store review. If
this file ever states the product type in two places again, delete one of them.

⚠️ Once billing is live the figure **shown** must come from `ProductDetails.price` — the
store's own localised, tax-inclusive string — never from the constant in `PremiumPlan`,
which cannot follow a currency, a regional tax rule, or a price change.
`premium_price_note` already tells the user that the store's price is the one they pay.

**Definition of done (2B):**
- ✅ Routes API key injected via `--dart-define=ROUTES_API_KEY=…`, never committed
  (`ApiKeys.googleRoutes`, plus the Codemagic build args).
  ⚠️ **It cannot be restricted per-platform, and the original wording of this bullet was
  wrong to assume it could.** Android/iOS application restrictions only apply to the *SDK*
  keys committed in `AndroidManifest.xml` and `AppDelegate.swift`; Routes is a web service,
  where Google honours only IP restrictions. The available protection is therefore
  "API restriction: Routes API" **plus a daily quota cap**, and that is what must be set.
  If that residual risk is not acceptable to the client, the fix is the same one §2.1 used
  for the news key — move the call behind a Cloud Function and make the key a Functions
  secret. That is a scope decision, not a code change to make silently: only the endpoint
  in `RouteService` changes.
- ✅ `test/route_test.dart` covers the polyline decoder (including truncated and junk
  input), the response parser, the duration rounding, the deep-link shape, and the copy in
  all six languages against §10.
- ✅ The key exists and works (2026-08-27). Verified by calling `computeRoutes`
  directly: DRIVE, WALK and TRANSIT all return 200 with a polyline, and the call
  succeeding from a **desktop** is itself the proof that Application restrictions are
  set to None — an Android-restricted key would have returned 403, because
  `RouteService` posts through `package:http` and therefore sends no
  `X-Android-Package`/`X-Android-Cert` headers for Google to check.
- ⏳ **Still owed for 2.4: hands-on QA on an Android physical device** — all three modes
  on screen, the 5-minute cache proving itself on R8, the deep link landing in the
  Google Maps app, and the location-denied path. A working key is not an accepted
  feature.
- ✅ The paywall gates features **client-side only** at this stage; purchases are not yet
  live. Both QA overrides exist: `--dart-define=PREMIUM_OVERRIDE=true` for any build, and a
  debug-only switch in Profile. Neither can unlock a release build — the flag defaults to
  false and `qaUnlock` refuses outside `kDebugMode`, which `test/premium_test.dart` asserts.
- ✅ `test/premium_test.dart` covers entitlement expiry, the storage round trip (including
  every malformed record that must drop to free rather than grant access), the free-tier
  trimming, and the paywall copy in all six languages against §10 plus the store
  disclosure rules.
- ⏳ **Still owed for 2.5: hands-on QA on an Android physical device** — each gate with the
  QA switch off and on, and the padlock states.
- Store account setup (Play Console products, App Store Connect agreements/banking) is
  **started during this phase** even though 2.8 lands in 2C — review and banking approval
  have multi-day lead times and are the usual cause of slippage.

### Phase 2C — In-App Purchase, Legal Wording & Release (8,000 THB of work)

| Task | Description | Est. |
|---|---|---|
| 2.8 | **In-App Purchase integration** — Google Play Billing + Apple StoreKit, receipt validation, "Restore Purchases" | 3 weeks (partly parallel — see 2B) |
| 2.6 | **Legal-wording revision pass** on all new copy across all 6 language ARB files | 2 days |
| 2.7 | **QA** — regression test on existing Map / Scanner / SOS features, release build | 2–3 days |

**Task 2.6 — the audit is done, the enforcement is permanent (2026-08-24).** All 216
keys were read in all six languages: **no §10 violation was found**, and
`test/wording_test.dart` now holds that line for every string added from here on. See
"How this is enforced" at the end of §10, including what the linter deliberately does not
cover. What is left of 2.6 is the copy task 2.8 has not written yet, which the linter
picks up automatically.

⚠️ The wording rules are **§10**. An earlier draft of the bullet below pointed at §8,
which is the build-commands section — a reviewer following that reference would have
checked the wrong thing and concluded the copy was fine.

#### Task 2.8 — where it actually stands (2026-08-31)

**The client side is built and tested. Two things are left, and neither is code
this project can finish alone.**

| Piece | State |
|---|---|
| `BillingService` + `InAppPurchaseBilling` | ✅ built — `lib/features/premium/services/billing_service.dart` |
| `purchase()` / `restore()` on the store | ✅ built, 17 tests in `test/billing_test.dart` |
| Acknowledge (never consume) | ✅ built and pinned by test |
| Pending purchases, cancellations, errors, retired product ids | ✅ each has its own outcome and its own copy in six languages |
| Store-localised prices on the paywall | ✅ `PremiumProvider.storeProducts()` |
| Firestore restore copy | ✅ retired — nothing writes it |
| **Receipt validation** | ❌ needs a Cloud Function; see below |
| **A real purchase, end to end** | ❌ needs products in the stores, which needs the Payments Profile (§5) |

🚨 **`PremiumProvider` takes its `BillingService` as an optional argument that
defaults to null.** That is what lets every widget test build a screen without
opening a platform channel — and it means *forgetting to pass one in
`main.dart` is completely silent*: the app compiles, analyze is clean, every
test passes, and every user is quietly told billing is unavailable forever.
`test/main_wiring_test.dart` reads `main.dart` and fails if the argument goes
missing. **Do not delete that test to make a refactor pass.**

🚨 **`grantPurchase` takes `expiresAt` now, not `purchasedAt`.** The old
signature computed `purchasedAt + plan.duration`, which is right for a
fixed-length pass and wrong for a subscription — and on a *restore*, where the
store reports the original subscription date, it would hand someone six months
into a monthly plan an expiry five months in the past and lock them out of what
they are paying for. `PremiumProvider._horizonFor` documents what is passed
instead and exactly what it over-grants.

**What receipt validation would buy, and what its absence costs.** A client
cannot learn the real renewal date; that needs Play's Developer API or Apple's
verifyReceipt, called from somewhere the user does not control. Without it the
app grants access for one plan period from each confirmation and re-confirms on
every launch. The gap: someone who cancels and never opens the app online again
keeps access until the horizon — at most one billing period. That is the
specific, bounded cost of not having the function, and the reason to build it
rather than a detail to leave unsaid.

**The 3-day trial is still granted in-app** (`startTrialIfEligible`). Moving it
to a store introductory offer is still the plan and is still not done. When it
happens, `premium_trial_note` must be rewritten in all six languages in the same
commit, and so must §4 of the web admin's `/terms` page — an in-app trial lapses,
a store offer converts into a paid subscription. `wording_test.dart` fails the
moment the mechanism goes while the copy stays.

**Definition of done (2C):**
- Purchase, restore and gate-unlock verified on an Android physical device (sandbox) and on
  iOS via cloud CI.
- Receipt validation does not require adding Firebase Auth to the app (§7) — if a
  server-side check is used, it goes through a Cloud Function, not client rules.
- Every new string, in all six languages, passes **§10** — which now means
  `flutter test test/wording_test.dart` is green rather than that somebody read it.
- Android AAB + iOS build produced from CI; §8 commands still work from a clean checkout.

**Not included in this quotation:** Google/Apple revenue share (15–30% per transaction),
domain and annual cloud/server costs, and any post-release feature work.

---

## 5. เงื่อนไขการชำระเงิน (Payment Terms — ฉบับแก้ไข 11/08/2026)

**เหตุผลที่แก้ไข:** ลูกค้าโอนได้สูงสุด **10,000 บาท/ครั้ง** จึงแบ่งงวดที่เหลือใหม่ให้ทุกงวด
ไม่เกิน 10,000 บาท และผูกกับการส่งมอบงานจริงของ Phase 2A / 2B / 2C

### สรุปยอด

| รายการ | จำนวนเงิน (THB) |
|---|---|
| มูลค่างานตามใบเสนอราคาเดิม (Phase 1 Web Admin 9,000 + Phase 2 Smart Map 23,000) | 32,000.00 |
| ชำระแล้ว — งวดที่ 1 (9,600) + งวดที่ 2 (8,400) + งวดที่ 3 (6,000) ณ 2026-08-23 | −24,000.00 |
| **คงเหลือที่ต้องชำระ** | **8,000.00** |

> เงินที่ชำระมาแล้ว 9,600.00 ครอบคลุมงาน **Phase 1 Web Admin ทั้งก้อน (9,000.00)** และ
> เหลือเครดิตยกไป Phase 2 อีก **600.00** ซึ่งนำไปหักในงวดถัดไปแล้ว

### ตารางงวดชำระใหม่

| งวด | เงื่อนไข / Milestone | ยอดชำระ (THB) | ยอดคงเหลือหลังชำระ |
|---|---|---|---|
| ✅ ชำระแล้ว | เริ่มโครงการ + ส่งมอบ Web Admin Dashboard (Phase 1 เดิม) | 9,600.00 | 22,400.00 |
| ✅ ชำระแล้ว | ส่งมอบ **Phase 2A** — Safety Radar + Alert Zone card + Filter/schema (9,000 − เครดิตยกมา 600) | **8,400.00** | 14,000.00 |
| ✅ ชำระแล้ว | **Phase 2B** — Route Suggestion + Paywall UI & feature gating | **6,000.00** | 8,000.00 |
| งวดที่ 4 | ส่งมอบ **Phase 2C** — IAP + Legal Wording + QA + Release Build (ปิดงาน) | **8,000.00** | 0.00 |
| | **รวมที่ต้องชำระเพิ่ม** | **8,000.00** | |

🚨 **งวดที่ 3 ถูกชำระก่อนการตรวจรับ (2026-08-23) และหนี้ก้อนนั้นเพิ่งปิดไปครึ่งหนึ่ง
(2026-08-27).** `ROUTES_API_KEY` ถูกสร้างและใส่ในไฟล์ secret แล้ว ทดสอบยิง
`computeRoutes` จริงผ่านทั้งสามโหมด — DRIVE 5,911 ม./18 นาที · WALK 5,117 ม./75 นาที ·
TRANSIT 5,917 ม./49 นาที ทุกโหมดคืน polyline ปกติ HTTP 200

การที่ `curl` จากเครื่องเดสก์ท็อปยิงผ่าน **พิสูจน์ในตัวว่า Application restriction ตั้งเป็น
None ถูกต้อง** — ถ้าตั้งเป็น Android apps ตามแบบ key ตัวอื่น คำสั่งนั้นจะได้ 403

**ที่ยังค้าง:** QA บนเครื่องจริง R1–R15 (`QA_PHASE_2B.md` §3) ยังไม่ได้ทำ · key ที่ใช้ได้
แปลว่าฟีเจอร์ *รันได้* ไม่ได้แปลว่า *ตรวจรับแล้ว*

- ทุกงวด **ไม่เกิน 10,000.00 บาท** ตามข้อจำกัดของลูกค้า ✔
- แต่ละงวดเรียกเก็บ **หลังส่งมอบ build ให้ทดสอบ** และลูกค้าตรวจรับตาม *Definition of done*
  ของเฟสนั้นใน §4
- ราคานี้เป็น **ค่าพัฒนาซอฟต์แวร์เท่านั้น** ไม่รวมค่าโดเมน / Cloud Server รายปี และไม่รวม
  ส่วนแบ่งรายได้ Google/Apple (15–30% ต่อรายการ)
- หากต้องการแบ่งย่อยกว่านี้ ให้แตกจากงวดที่ 4 ก่อน (2C มีงานย่อย 3 ชิ้นที่แยกส่งมอบได้)

---

### การเปลี่ยนแปลงที่ตกลงเมื่อ 2026-08-30

| เรื่อง | เดิม | ใหม่ |
|---|---|---|
| รูปแบบสินค้า | บัตรผ่านจ่ายครั้งเดียว 2 แบบ | **Subscription ต่ออายุอัตโนมัติ 2 แบบ** |
| แพ็กเกจสั้น | 14 วัน $7 | **รายสัปดาห์ $3.50** (ไม่มีรอบ 14 วันให้เลือกในสโตร์) |
| แพ็กเกจยาว | 30 วัน $10 | **รายเดือน $10** |
| กู้คืนบน iOS | ทำไม่ได้ ลูกค้ายอมรับ 23/08 | **ทำได้แล้ว** — ข้อจำกัดหมดไปพร้อมการเปลี่ยนประเภทสินค้า |

🚨 **งานที่อนุมัติเพิ่มเมื่อ 2026-08-30 และยังไม่ได้เริ่ม — อยู่นอกวงเงิน 32,000 บาท**

- ค้นหาสถานที่ด้วย **Google Places** (API ใหม่ มีค่าใช้จ่ายต่อการเรียก)
- **แถวไอคอนหมวดหมู่** บนหน้าแผนที่
- **การ์ดหมวดหมู่พร้อมรูป** — ต้องเพิ่มช่องอัปโหลดรูปใน CMS ด้วย

ลูกค้าอนุมัติให้ทำ "ทุกอย่างที่ไม่มีความเสี่ยงทางกฎหมาย" · **Smart Alerts และ Offline
Map ถูกตัดออกในการสนทนาเดียวกัน** — Offline Map เพราะการเก็บแผนที่ Google ไว้ในเครื่อง
ผิดเงื่อนไขการใช้งาน ซึ่งเข้าข่ายความเสี่ยงทางกฎหมายตามเกณฑ์ที่ลูกค้าตั้งเอง

⚠️ ยังไม่ได้ตกลงราคาสำหรับสามรายการข้างบน — ต้องคุยก่อนเริ่ม ไม่ใช่ตอนส่งมอบ

---

## 6. แผนการดำเนินงาน (Timeline)

| ลำดับ | Phase | กิจกรรม | กำหนดการ | สถานะ |
|---|---|---|---|---|
| 1 | — | Web Admin Dashboard (Phase 1 เดิม ทั้ง 5 รายการ) | 2026-07-20 → 2026-08-07 | ✅ ส่งมอบแล้ว |
| 2 | 2A | Safety Radar core + geo-radius logic | สัปดาห์ที่ 1 (2026-08-12 → 2026-08-18) | ✅ โค้ดเสร็จ 2026-08-11 |
| 3 | 2A | Alert Zone proximity card + Filter panel + schema 3→11 | สัปดาห์ที่ 2 (2026-08-19 → 2026-08-25) | ✅ โค้ดเสร็จ 2026-08-11 — รอทดสอบบนเครื่องจริง |
| 4 | 2B | Route Suggestion (Routes API) | สัปดาห์ที่ 3 (2026-08-26 → 2026-09-01) | โค้ดเสร็จ 2026-08-19 · รอ QA บนเครื่องจริง |
| 5 | 2B | Paywall UI + feature gating *(+ เปิดบัญชี/สร้าง product ใน Play & App Store คู่ขนาน)* | สัปดาห์ที่ 4 (2026-09-02 → 2026-09-08) | โค้ดเสร็จ 2026-08-19 · **แพ็กเกจใหม่ 2026-08-22** · รอ QA บนเครื่องจริง |
| 5.1 | — | แพ็กเกจใหม่ 2 แบบ + ทดลองฟรี 3 วัน + entitlement บน Firestore | — | ✅ 2026-08-22 (ไม่คิดค่าใช้จ่าย) |
| 5.2 | — | ย้าย Radar เข้าหน้าแผนที่ (ข้อ ข) | — | ✅ 2026-08-23 (ไม่คิดค่าใช้จ่าย) |
| 5.3 | — | ชุดทดสอบ widget + on-device + QA gate (§7.5) | — | ✅ 2026-08-23 |
| 6 | 2C | IAP integration (Play Billing / StoreKit) + receipt validation | สัปดาห์ที่ 5–6 (2026-09-09 → 2026-09-22) | รอดำเนินการ |
| 7 | 2C | Legal-wording revision + QA regression + release build | สัปดาห์ที่ 6–7 (2026-09-23 → 2026-09-29) | รอดำเนินการ |

*ความเสี่ยงหลักด้านเวลา: การอนุมัติบัญชี/สินค้าใน Play Console และ App Store Connect ซึ่ง
ไม่ได้อยู่ในการควบคุมของผู้พัฒนา — จึงเริ่มดำเนินการตั้งแต่สัปดาห์ที่ 4*

---

## 7. Strict Out of Scope (DO NOT CODE)

- **NO** user registration / authentication / login screens in the Flutter app
  (Firebase Auth omitted for the app; the CMS's own staff login is separate — §2.4).
  The paywall does **not** change this: purchases attach to the Google/Apple account, so
  the app still has no identity of its own — see "What 2.5 actually added" in §4.
- **NO** user scan-history logs or personal profile tracking databases.
- **NO** rating forms or community comment inputs.
- **NO** live chat or premium support layout simulators.
- **NO** second CMS or admin UI inside the app.
- **NO** background/geofencing push notifications for alert zones — Phase 2A task 2.2 is a
  **foreground, on-open** check only.

---

## 7.4 Decisions taken 2026-08-29, and what is deferred

Six findings were put to the client in one pass. Their answers, recorded so a
deferral is never mistaken for an approval:

| # | Finding | Decision |
|---|---|---|
| 1 | Gemini key exposed in a chat transcript | Client holds the real key; rotation is theirs to do |
| 2 | newsdata query set 2 produced 7 junk articles out of 9 | **Dropped** — see `functions/index.js` |
| 3 | The QA switch wipes a trial, and will wipe a real purchase in 2.8 | **Deferred to 2C** |
| 4 | Routes key readable in the APK | **Moved behind a Cloud Function** — see below |
| 5 | "About" heading and body prose are English-only | **Deferred to 2C**, task 2.6 |
| 6 | "Partner Business" printed twice in one card | **Fixed** — the badge went, the header stayed |

🚨 **3 and 5 are deferred, not resolved.** Do not close them, and do not let a
later pass rediscover them as new.

**Task 2.8 must fix #3 before wiring billing.** `PremiumProvider.qaLock()`
calls `_store.clear()`, which destroys whatever entitlement is present rather
than only the one the switch granted. Today that costs a 3-day trial that
`trialUsed` then refuses to re-grant; once purchases are real it will silently
drop a paid pass out of the local cache.

### Route Suggestion now goes through a Cloud Function

`RouteService` posts to `computeRoute` in `asia-southeast1` instead of calling
`routes.googleapis.com` directly, and `ROUTES_API_KEY` is a Functions secret.
The app ships no Routes key at all — `ApiKeys.googleRoutes` is gone, and so is
the `--dart-define` in `tools/build-delivery.sh`.

🚨 **The function is unauthenticated, and that is not the finished state.**
Moving the key stops it leaking out of the APK; it does not stop anyone who
finds the URL from spending the project's Routes quota — an open endpoint is
arguably easier to abuse than a key someone has to unzip an APK for. **Firebase
App Check** is what closes it, and it attests the app binary rather than a
user, so it works under §7's no-accounts rule. Until it is enabled, **the daily
quota cap in Cloud Console is the only bound on the damage — keep it set.**

⚠️ **Nothing works until the function is deployed.** `tools/build-delivery.sh`
now refuses to build unless `computeRoute` answers, because a build made before
the deploy looks perfect and has a dead feature:

```bash
firebase functions:secrets:set ROUTES_API_KEY
firebase deploy --only functions:computeRoute
```

---

## 7.5 Testing — the pyramid, and what it deliberately does not cover

Added 2026-08-23. Before that the project had excellent **manual** checklists and
nothing that ran itself, so every feature change cost a full hands-on pass and the
cases that slipped were never the hard ones — they were the ones tested a fortnight
earlier and assumed still fine.

| Layer | Where | Runs on | Catches |
|---|---|---|---|
| Unit | `test/*_test.dart` | dev machine, ~4s | logic, models, geo maths, six-language copy |
| Wording | `test/wording_test.dart` | dev machine, ~1s | §10 over **every** key in **all six** languages |
| Widget | `test/paywall_widget_test.dart` | dev machine, ~3s | whether the **screen** draws what the model says |
| On-device | `integration_test/app_test.dart` | emulator/handset, ~2m | real boot with Firebase, tab navigation, first-run trial, language switch |
| Manual | `QA_PHASE_2B.md` (workspace root) | real handset | camera, mic, real GPS, Maps deep link, purchases |

```bash
export PATH="/c/Users/werapat/flutter/bin:$PATH"
flutter analyze
flutter test                                    # unit + widget
flutter test integration_test -d emulator-5554  # on-device
```

**Rules that keep this useful rather than decorative:**

- Anything provable without a device belongs in the bottom two layers. A test left
  in the on-device suite that did not need to be there is a tax paid on every run.
- 🚨 `integration_test` **wipes SharedPreferences on the device**. Emulator or a
  dedicated test handset only.
- The on-device suite builds its own widget tree rather than calling `main()`:
  `main()` initialises Firebase, and a second call throws `duplicate-app`. Firebase
  is initialised once in `setUpAll` instead.
- A green run proves less than it looks like. Camera, microphone, a real GPS fix,
  the Google Maps deep link and anything about iOS are **untested, not passing** —
  say so out loud rather than letting the count imply coverage.
- The test count must never go **down**. A deleted test is a deleted safety net.

**The QA gate** — `.claude/workflows/feature-qa.js` plus the four `qa-*` agents in
`.claude/agents/` — runs these checks from four angles that fail differently and
puts every finding in front of two skeptics before reporting it. Run it after any
feature lands. Full rationale and the team process it belongs to: `DEV_PROCESS.md`,
beside this file.

Both live **inside this repo on purpose** (moved there 2026-08-23): a gate this
file makes mandatory has to be version-controlled, reviewable and restorable like
anything else it governs. `QA_PHASE_2B.md` and `INTEGRATION_TEST.md` stay at the
workspace root because they cover both repos.

🚨 **The gate's first real run returned BLOCKED against this very file.** The
2026-08-22 package rewrite added the new store-setup block without deleting the
old one, so CLAUDE.md simultaneously ordered consumables and subscriptions under
ids that no longer exist. Run the gate before believing a change is finished —
the worst thing it caught that day was in the documentation, not the code.

---

## 7.6 Handing a build to the client for acceptance

Two builds go out, and the reason there are two matters: **a fresh install grants
the 3-day trial immediately**, so anyone testing the real build sees everything
unlocked and never reaches the paywall — which is precisely task 2.5, the thing
they are supposed to be accepting.

| Build | What it is | Why |
|---|---|---|
| `thaishield-2B-ตรวจรับ.apk` | `--debug --split-per-abi`, arm64 | `kDebugMode` is true, so the QA switch in Profile exists and the tester can flip between free and Premium in one tap |
| `thaishield-2B-เวอร์ชันจริง.apk` | `--release --split-per-abi`, arm64 | What a real user gets. No switch, and `qaUnlock` refuses outside debug on top of that |

```bash
bash tools/build-delivery.sh
```

That is the whole command. The script reads the three `--dart-define` keys from
`thaishield_ai-secret.txt` (outside git) and **never prints a value**, runs
analyze and the test suite first, builds both variants split per ABI, and stages
them in the workspace `delivery/` folder under the names `DELIVERY_2B.md` uses.
Typing the defines by hand is how a key ends up in a shell history, a build log,
or a chat transcript.

If `ROUTES_API_KEY` is missing the script **still builds** — everything except
Route Suggestion is worth shipping — but says so loudly, because a build without
it looks complete while silently dropping half of task 2.4.

`--split-per-abi` is not optional for a handover: the fat debug APK is 206 MB and
the arm64 slice is 107 MB, which is the difference between a client installing it
and a client giving up. arm64-v8a covers every current Android handset.

Binaries go to the workspace `delivery/` folder (outside git); the acceptance
guide the client actually follows is `DELIVERY_2B.md` beside this file, so it is
versioned and reusable for 2C.

✅ **Route Suggestion is in both builds from 2026-08-27**, when the key was
created and verified live against `computeRoutes` in all three travel modes. The
builds before that date report the feature as unavailable rather than failing,
which is correct behaviour and not a bug to chase if an old APK resurfaces.

---

## 8. Firebase / Build Commands

```bash
# Flutter + Firebase (once)
dart pub global activate flutterfire_cli
npm install -g firebase-tools
firebase login
flutterfire configure          # generates lib/firebase_options.dart (Android + iOS)
```

```bash
# Cloud Functions (news sync — §2.1)
cd functions && npm install                       # once, and after editing package.json
firebase functions:secrets:set NEWSDATA_API_KEY   # once, or when the key rotates
firebase deploy --only functions:syncTravelAlerts
```

Cloud Functions require the Firebase project to be on the **Blaze (pay-as-you-go) plan** —
they cannot deploy on Spark even though actual usage stays inside Blaze's free tier. Check
at `https://console.firebase.google.com/project/thaishield-ai-790eb/usage`.

**Project commands**

| | |
|---|---|
| Run app | `flutter run --dart-define=GEMINI_API_KEY=… --dart-define=GCS_STT_KEY=… --dart-define=ROUTES_API_KEY=…` |
| Fetch plugins | `flutter pub get` |
| Clean caches | `flutter clean` |
| Analyze | `flutter analyze lib/` |
| Android APK | `flutter build apk --split-per-abi --release` |
| Android Bundle | `flutter build appbundle --release` |
| iOS | CI only (Codemagic pipeline) |

---

## 9. Firestore Security Rules

Rules live in `firestore.rules` in this repo as a backup/reference; the live rules are
edited in Firebase Console → Firestore Database → Rules.

- `price_standards`, `partner_locations`, `alert_zones` are **public read, no write**
  (`allow read: if true; allow write: if false;`). The app has no Firebase Auth, so reads
  must stay open or Map/Scanner/Radar stop working entirely.
- `travel_alerts_cache` is also **public read, no write** — written only by
  `syncTravelAlerts` through the Admin SDK, which bypasses rules; `allow write: if false`
  exists solely to block clients.
- 🚨 **Never use Firebase's default "test mode" rule**
  (`allow read, write: if request.time < timestamp.date(...)`) beyond initial local
  testing — it has an expiry date and **silently denies all reads once it passes**, with no
  code change needed to trigger it. This has already happened once. If Map/Scanner suddenly
  fail in production with no related code or dependency change, **check the Rules tab
  first**, before suspecting Maps API keys or billing.
- The CMS writes via the Admin SDK and needs no rule changes. Any future authenticated
  write access must be scoped to that specific case — **never** broaden the public rule to
  allow writes from the Flutter app.
- 🚨 **`entitlements` is the one exception, and it is now obsolete as well as
  temporary.** It is the only collection an app client may write to. It existed because a
  one-time pass had to be recoverable on a second device and the app has no identity to
  file it under (§7) — but the products became auto-renewing subscriptions on 2026-08-30
  and both stores replay those themselves, so the question it answered is answered better
  elsewhere. Task 2.8 should stop writing to it and drop `create` to `if false`. Reads are open — a
  store transaction id identifies nobody and is not guessable — and `create` is shape-
  checked to a known product id plus a timestamp, with `update`/`delete` refused so an
  existing record cannot be extended. **This is not a security boundary**: the store
  receipt is the source of truth, and task 2.8 moves the write into a Cloud Function that
  validates the receipt, at which point `create` drops to `if false`. Do not build
  anything that treats a document here as proof of payment.

---

## 10. Legal Safe Wording Guide (MANDATORY — ALL user-facing text)

ThaiShield AI displays pricing and travel-safety information. To minimise legal risk
(defamation, accusation, damages claims against shops, individuals or areas), **all UI
copy, alerts, scan results, radar cards, paywall copy and map screens MUST use neutral,
statistical, informational wording** — never accusatory or judgmental language.

Applies to: widget text, ARB localization strings, Firestore seed data, **CMS-entered
content**, push notifications, and any AI-generated (Gemini) response shown to users.

### Wording replacement table

| Avoid (Never use) | Use instead |
|---|---|
| Scam | Travel Alert |
| Scammer | Community Alert |
| Tourist Scam | Tourist Advisory |
| Fraud | Price Information |
| Fraudulent Business | Community Reported Area |
| Overcharge | Higher Than Average |
| Rip-off Price | Above Typical Range |
| Cheating Tourists | Pricing Variation |
| Fake Price | Price Difference |
| Dangerous Shop | Travel Advisory |
| Unfair Shop | Community Feedback |
| Bad Business | User Experience Report |
| Unsafe Area | Travel Information Zone |
| Blacklist Shop | Watchlist Area |
| Tourist Trap | Tourist Caution Area |
| Price Gouging | Significant Price Variation |
| Exploitation | Unusual Pricing Pattern |
| "This Shop Is Expensive" | "Price Appears Above Local Average" |
| "This Shop Is Overcharging" | "Price Is Higher Than Typical Range" |
| "Avoid This Shop" | "Compare Before Purchasing" |
| "Do Not Buy Here" | "Consider Comparing Prices" |
| "This Taxi Is Cheating" | "Fare Appears Higher Than Average" |
| "This Merchant Is Dishonest" | "Pricing Information Available" |
| Verified Fair Price | Certified Fair Price |
| Guaranteed Fair Price | Participating Partner |
| Featured Partner / Government Approved | Partner Business |
| Safe Zone | Travel Information Area |
| Dangerous Zone | Tourist Advisory Area |
| Scam Area | Community Alert Zone |
| Fraud Zone | Travel Advisory Zone |

### Additional rules

- **Never** display shop names, logos or other shop-identifying info on the price-scan
  results screen (§2.2) — statistical variance only.
- **Never** use directly accusatory words: Scam, Fraud, Cheating, Overcharge, Rip-off,
  Dangerous, Unsafe, Blacklist, Exploitation, etc.
- Frame all price commentary statistically: "Average Price", "Price Variation",
  "Above Typical Range", "Significant Price Variation".
- Every screen showing price analysis (Scanner results, Map partner panel, **Radar cards**)
  **MUST display a disclaimer**:
  - **EN:** "This information is generated from statistical and community-based data and is
    intended for informational purposes only. Actual prices may vary."
  - **TH:** "ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น
    ราคาจริงอาจแตกต่างกันได้"
- The CMS's automated linter checks **English only** — Thai free-text from staff
  (`description_th`) is unchecked and needs human review before it ships (§3).

The app's goal is to **inform** tourists so they can decide for themselves — never to
**judge or accuse** any specific shop, person or area. Apply this to every new feature and
copy change, including all Phase 2A/2B/2C work.

### How this is enforced (added 2026-08-24, task 2.6)

`test/wording_test.dart` reads the key set **out of `appStrings` itself** and checks all
six languages. A string added tomorrow is covered tomorrow, with nobody remembering to
add it to a list.

That shape was chosen because the previous one had quietly failed. Four tests each
carried a `§10 wording` block over a hand-written list of their own feature's keys, and
each checked the **English entry only**. Measured before the rewrite: **63 of 216 keys,
29%, English-only.** Unchecked among the other 153 were `variance_above` and
`variance_significant` — the app telling a tourist what a scanned price *means*, which is
the exact sentence §10's replacement table was written to govern — plus every `radar_*`,
`proximity_*`, `alert_category_*`, `scanner_*` and `sos_*` string.

**Legal exposure does not stop at the English column.** A Thai translation reading
"ร้านนี้โกง" while the English says "Price Is Higher Than Typical Range" is precisely the
accusation this guide exists to prevent — and, shipping Thai-first to an audience in
Thailand, it is the version most likely to be read by the business being described.

⚠️ **Banned terms are patterns, not substrings, and the Russian column is why.** `опасн`
("danger") is a substring of `безопасн` (“**safe**”), so a contains-check reports
"Радар безопасности" — *Safety* Radar — as a violation. On first measurement that was
five false alarms out of seven Russian hits. A linter wrong five times out of seven is one
that gets switched off, so `(?<!без)опасн` carries a lookbehind and `небезопасн` is listed
separately.

**Exemptions are per (key, term), never per key**, and each carries its reason in the
file. `safety_tip_5` and `safety_tip_6` are exempt from *avoid* only — the midday sun and
walking alone at night are not a business and not an identified place, which is the thing
§10 actually protects. They were exempted rather than reworded on purpose: rewriting copy
in six languages to satisfy a linter written in the same change would add five unreviewed
translations to remove a risk judged not to exist.

🚨 **What the linter does not see** — say this out loud rather than letting a green run
imply coverage:

- **The SOS translation output.** It relays the tourist's *own* emergency speech, so if
  they say someone is overcharging them, the app must translate that faithfully. Sanitising
  it would break the feature's purpose at the worst possible moment. Deliberately out of
  scope — do not "fix" it later.
- **Thai free text staff enter in the CMS** (`description_th`) — §3 already flags that the
  CMS linter reads English only, and this test runs against the app's own strings, not
  Firestore.
- **Firestore seed data.**
- ✅ **String literals written straight into widgets — fixed 2026-08-27, and now
  tested.** The Map's partner sheet used to pass `'VERIFIED'`, `'FAIR PRICE'`,
  `'PARTNER'`, `'ABOVE TYPICAL RANGE'` and `'Verified Partner'` straight into its
  badge widget: English-only in a six-language app, and **"Verified" is the word
  §10's table replaces with "Certified"** — which the Radar had been getting right
  the whole time from `radar_badge_certified`. The same partner therefore read
  "Certified Fair Price / ราคามาตรฐานที่รับรอง" on one screen and "VERIFIED" on
  another. All five now read from the table, and the three badge keys are shared
  with the Radar so the two screens can no longer drift.

  `test/wording_test.dart` **reads `map_screen.dart` as source** and fails on any
  `label:` given a string literal — the only way to catch text that never reaches
  `appStrings`. On its first run it immediately found four more: the legend chips
  **Travel Info / Advisory / Alert Zone / Partner**, which sat across the top of
  every screenshot of every QA pass ever run on this app and were never noticed.
  Their English is unchanged; the five missing languages were added.

- ✅ **The invented reviews are gone (2026-08-28).** The partner sheet used to
  show "นักท่องเที่ยว A/B/C" / "Traveler A/B/C" with star ratings and opinions
  ("ราคาตรงตามที่แสดงในแอป") under a **named, real business**. They carried a
  ตัวอย่าง label, but a reader seeing them beside a real shop's name and rating
  takes them as reports about that shop. §10 exists to stop the app making claims
  about identified businesses; inventing favourable ones is the same exposure
  pointed the other way. `_Review`, `_sampleReviews`, `_ReviewsSection` and
  `_ReviewCard` were deleted outright.

  🚨 **The review *count* went with them, and it was the worse half.**
  `reviewCount = 80 + (partner.id.hashCode.abs() % 600)` — a number derived from
  a hash of the document id and printed as "(215 รีวิว)" beside a real shop.
  `partner_locations` has no review field at all (§3), so nothing backed it, and
  unlike the review text it carried **no ตัวอย่าง label** — it read as hard data.
  If a real count ever exists it belongs in Firestore first. The `rating` field
  stays: that one is real, entered by staff through the CMS.

- ⚠️ Two milder gaps, deliberately left: `_riskLabel`/`_riskLabelTh` in
  `map_screen.dart` and `formatDistance` in `geo_utils.dart` are **Thai-or-English
  pairs**, so the other four languages fall back to English rather than to Thai.
  Wrong, but not a §10 risk and not a broken string — worth folding into the table
  when those screens are next touched.

The four older per-feature `§10 wording` blocks are now redundant but stay: a deleted
test is a deleted safety net (§7.5), and they assert other things besides.

---

## 11. UI Theme & Color Guide (MANDATORY — every screen, current and future)

ThaiShield AI uses one consistent dark-green "ranger" theme for the top header and the
bottom navigation bar on every screen, so the user never sees a jarring color seam between
header, page body and bottom nav. This was fixed once already (bottom nav was tinted navy
`#0D1B2A` while headers used green `#0A1810`) — do not reintroduce that mismatch.

### Core palette

| Role | Color | Hex |
|---|---|---|
| Header background / bottom nav tint (primary brand color) | dark green | `#0A1810` |
| Page body background | light grey | `#F3F5F7` |
| Card / heading text on white cards | dark navy | `#0D1B2A` |
| Accent gold (brand title, active highlights) | gold | `#FFB300` |
| Accent blue (info, scan, profile icons) | sky blue | `#4FC3F7` |
| Accent green (safe / verified / success) | green | `#2E7D32` |
| Accent red (alerts / SOS / danger) | red | `#EF5350` / `#D32F2F` |
| Secondary muted text | grey | `#90A4AE` |

### Rules

- Any screen with a top header bar **must** use `#0A1810` as the header background (see
  `_buildHeader` in `home_tab.dart` / `profile_screen.dart` for the canonical pattern:
  logo + "ThaiShield AI" gold title + page title + subtitle).
- The bottom navigation bar (`lib/features/home/widgets/main_bottom_nav.dart`) tints its
  skyline background image with the **same** `#0A1810` — never navy or anything else. If
  the header color changes, update the bottom nav tint in the same change.
- `#0D1B2A` is reserved for **text/icons on white cards**, never a full-screen or header
  background — keep the two dark colors distinct in their roles.
- Page body background outside cards defaults to `#F3F5F7` unless an approved mockup says
  otherwise (Smart Map's white toolbar is an intentional, already-approved exception —
  don't "fix" it unasked).
- New screens from Phase 2A/2B/2C (**Radar sheet, Filter panel, Route preview, Paywall**)
  default to this same header + bottom-nav treatment, with the risk-level colors reused
  from the map: green = safe, amber = caution, red = alert.