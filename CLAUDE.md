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
| Staff auth | Google Sign-In with domain restriction, Firebase Auth — **CMS only** |
| Manages | `price_standards`, `partner_locations` (with real photo upload to Firebase Storage), `alert_zones` (interactive Google Maps polygon editor) |

- Staff auth in the CMS **does not contradict** §6 "no Firebase Auth in the app" — that
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
| Firestore rules | public read, **no client writes** (see §7) |
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
name         string
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
name            string
risk_level      string           // "safe" | "caution" | "danger"
description_en  string
description_th  string
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
- **§8 wording rules apply to CMS-entered text too.** `alert_zones` descriptions run through
  an automated linter in the CMS, but it only recognises **English** terms — **Thai copy is
  unchecked** and still needs human review. Anything the app displays verbatim from
  `description_th` carries that risk.

---

## 4. Remaining Scope — Smart Map Premium V2 (Option A, In-App Purchase)

Split into **three delivery phases**. Each ends in a demo-able build, which is what
triggers the corresponding invoice in §5.

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

| Task | Description | Est. |
|---|---|---|
| 2.4 | **Route Suggestion** — Google Directions API integration, route preview UI, travel-mode toggle, "Open in Google Maps" deep link | 1 week |
| 2.5 | **Paywall / plan-comparison screen** (Monthly / Yearly / Lifetime) + client-side feature gating for Radar details, Filter and Route Suggestion | 3–4 days |

**Definition of done (2B):**
- Directions API key restricted per-platform and injected via `--dart-define`, never
  committed. Watch the Directions quota — it bills per request.
- The paywall gates features **client-side only** at this stage; purchases are not yet live.
  A debug/override flag must let QA unlock without paying.
- Store account setup (Play Console products, App Store Connect agreements/banking) is
  **started during this phase** even though 2.8 lands in 2C — review and banking approval
  have multi-day lead times and are the usual cause of slippage.

### Phase 2C — In-App Purchase, Legal Wording & Release (8,000 THB of work)

| Task | Description | Est. |
|---|---|---|
| 2.8 | **In-App Purchase integration** — Google Play Billing + Apple StoreKit, receipt validation, "Restore Purchases" | 3 weeks (partly parallel — see 2B) |
| 2.6 | **Legal-wording revision pass** on all new copy across all 6 language ARB files | 2 days |
| 2.7 | **QA** — regression test on existing Map / Scanner / SOS features, release build | 2–3 days |

**Definition of done (2C):**
- Purchase, restore and gate-unlock verified on an Android physical device (sandbox) and on
  iOS via cloud CI.
- Receipt validation does not require adding Firebase Auth to the app (§6) — if a
  server-side check is used, it goes through a Cloud Function, not client rules.
- Every new string in all 6 ARB files passes §8.
- Android AAB + iOS build produced from CI; §9 commands still work from a clean checkout.

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
| ชำระแล้ว (งวดที่ 1 เดิม 30%) | −9,600.00 |
| **คงเหลือที่ต้องชำระ** | **22,400.00** |

> เงินที่ชำระมาแล้ว 9,600.00 ครอบคลุมงาน **Phase 1 Web Admin ทั้งก้อน (9,000.00)** และ
> เหลือเครดิตยกไป Phase 2 อีก **600.00** ซึ่งนำไปหักในงวดถัดไปแล้ว

### ตารางงวดชำระใหม่

| งวด | เงื่อนไข / Milestone | ยอดชำระ (THB) | ยอดคงเหลือหลังชำระ |
|---|---|---|---|
| ✅ ชำระแล้ว | เริ่มโครงการ + ส่งมอบ Web Admin Dashboard (Phase 1 เดิม) | 9,600.00 | 22,400.00 |
| งวดที่ 2 | ส่งมอบ **Phase 2A** — Safety Radar + Alert Zone card + Filter/schema (9,000 − เครดิตยกมา 600) | **8,400.00** | 14,000.00 |
| งวดที่ 3 | ส่งมอบ **Phase 2B** — Route Suggestion + Paywall UI & feature gating | **6,000.00** | 8,000.00 |
| งวดที่ 4 | ส่งมอบ **Phase 2C** — IAP + Legal Wording + QA + Release Build (ปิดงาน) | **8,000.00** | 0.00 |
| | **รวมที่ต้องชำระเพิ่ม** | **22,400.00** | |

- ทุกงวด **ไม่เกิน 10,000.00 บาท** ตามข้อจำกัดของลูกค้า ✔
- แต่ละงวดเรียกเก็บ **หลังส่งมอบ build ให้ทดสอบ** และลูกค้าตรวจรับตาม *Definition of done*
  ของเฟสนั้นใน §4
- ราคานี้เป็น **ค่าพัฒนาซอฟต์แวร์เท่านั้น** ไม่รวมค่าโดเมน / Cloud Server รายปี และไม่รวม
  ส่วนแบ่งรายได้ Google/Apple (15–30% ต่อรายการ)
- หากต้องการแบ่งย่อยกว่านี้ ให้แตกจากงวดที่ 4 ก่อน (2C มีงานย่อย 3 ชิ้นที่แยกส่งมอบได้)

---

## 6. แผนการดำเนินงาน (Timeline)

| ลำดับ | Phase | กิจกรรม | กำหนดการ | สถานะ |
|---|---|---|---|---|
| 1 | — | Web Admin Dashboard (Phase 1 เดิม ทั้ง 5 รายการ) | 2026-07-20 → 2026-08-07 | ✅ ส่งมอบแล้ว |
| 2 | 2A | Safety Radar core + geo-radius logic | สัปดาห์ที่ 1 (2026-08-12 → 2026-08-18) | ✅ โค้ดเสร็จ 2026-08-11 |
| 3 | 2A | Alert Zone proximity card + Filter panel + schema 3→11 | สัปดาห์ที่ 2 (2026-08-19 → 2026-08-25) | ✅ โค้ดเสร็จ 2026-08-11 — รอทดสอบบนเครื่องจริง |
| 4 | 2B | Route Suggestion (Directions API) | สัปดาห์ที่ 3 (2026-08-26 → 2026-09-01) | รอดำเนินการ |
| 5 | 2B | Paywall UI + feature gating *(+ เปิดบัญชี/สร้าง product ใน Play & App Store คู่ขนาน)* | สัปดาห์ที่ 4 (2026-09-02 → 2026-09-08) | รอดำเนินการ |
| 6 | 2C | IAP integration (Play Billing / StoreKit) + receipt validation | สัปดาห์ที่ 5–6 (2026-09-09 → 2026-09-22) | รอดำเนินการ |
| 7 | 2C | Legal-wording revision + QA regression + release build | สัปดาห์ที่ 6–7 (2026-09-23 → 2026-09-29) | รอดำเนินการ |

*ความเสี่ยงหลักด้านเวลา: การอนุมัติบัญชี/สินค้าใน Play Console และ App Store Connect ซึ่ง
ไม่ได้อยู่ในการควบคุมของผู้พัฒนา — จึงเริ่มดำเนินการตั้งแต่สัปดาห์ที่ 4*

---

## 7. Strict Out of Scope (DO NOT CODE)

- **NO** user registration / authentication / login screens in the Flutter app
  (Firebase Auth omitted for the app; the CMS's own staff login is separate — §2.4).
- **NO** user scan-history logs or personal profile tracking databases.
- **NO** rating forms or community comment inputs.
- **NO** live chat or premium support layout simulators.
- **NO** second CMS or admin UI inside the app.
- **NO** background/geofencing push notifications for alert zones — Phase 2A task 2.2 is a
  **foreground, on-open** check only.

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
| Run app | `flutter run` |
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