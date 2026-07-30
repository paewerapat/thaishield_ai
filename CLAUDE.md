# ThaiShield AI - Project Blueprint & Developer Rules (MVP Version)

You are an expert Flutter & Firebase developer helper. You are assisting a developer working on a Windows/Linux environment (NO LOCAL MAC MACHINE AVAILABLE). Follow these specifications strictly.

## 1. Environment & Architecture Constraints
- **Framework:** Pure Flutter (Stable channel).
- **Local Dev OS:** Windows/Linux. **NEVER** command the user to run Mac-specific steps locally (e.g., `pod install`, `open ios/Runner.xcworkspace`, `xcodebuild`).
- **Local Testing:** Target **Android physical devices** via USB debugging for features requiring Camera and Microphone (STT).
- **iOS Strategy:** iOS builds will be handled via Cloud CI/CD (Codemagic/GitHub Actions) in the final phase. Write portable, cross-platform Flutter code.
- **State Management:** Provider or Riverpod (Keep business logic strictly decoupled from UI widgets).
- **Architecture:** Feature-First Structure. Create folders under `lib/features/` (e.g., `lib/features/onboarding/`, `lib/features/scanner/`, `lib/features/map/`, `lib/features/sos/`).

## 2. Core Features Scope & Logic (Budget 45,000 THB)

### Phase 1: Language Onboarding ✅ COMPLETE
- [x] First-launch screen to choose language: TH, EN, ZH, KO, RU, JA (6 languages incl. Thai per mockup).
- [x] Save global selection in Local App State using `shared_preferences` via `LocaleProvider`.
- [x] App labels localize automatically via ARB files + flutter_localizations.
- [x] Bottom navigation: 5 tabs — Home, Scan, Map, SOS, Profile.
- [x] Language can be changed anytime from Profile → Language tile (bottom sheet).
- [x] Android release build configured (keystore signing + Play Store AAB upload).

### Phase 1: Firebase Backend Setup ← IN PROGRESS
- [ ] Install FlutterFire CLI and run `flutterfire configure` to generate `firebase_options.dart`.
- [ ] Add `firebase_core` and `cloud_firestore` packages.
- [ ] Initialize Firebase in `main.dart`.
- [ ] Populate Firestore seed data via Firebase Console (price_standards, partner_locations, alert_zones).

#### Firestore Schema

**Collection: `price_standards`**
```
{
  id:         string,          // e.g. "pad_thai"
  name_en:    string,
  name_th:    string,
  name_zh:    string,
  name_ko:    string,
  name_ru:    string,
  name_ja:    string,
  min_price:  number,          // THB
  max_price:  number,          // THB
  category:   string,          // "food" | "transport" | "attraction"
  updated_at: timestamp
}
```

**Collection: `partner_locations`**
```
{
  id:           string,
  name:         string,
  lat:          number,
  lng:          number,
  type:         string,        // "restaurant" | "hotel" | "transport"
  rating:       number,        // 0.0 - 5.0
  is_verified:  boolean,
  price_tier:   string,        // "fair" | "caution" | "high"
  image_url:    string
}
```

**Collection: `alert_zones`**
```
{
  id:             string,
  name:           string,
  center_lat:     number,
  center_lng:     number,
  radius_km:      number,
  polygon:        array<GeoPoint>,  // area boundary points for map overlay (replaces circle radius display)
  risk_level:     string,      // "safe" | "caution" | "danger"
  description_en: string,
  description_th: string
}
```

**Collection: `travel_alerts_cache`** (written only by the `syncTravelAlerts`
Cloud Function — see Phase 2b below)
```
{
  id:            string,   // md5 of the article url, used as the doc id for idempotent upserts
  title:         string,
  description:   string,
  url:           string,
  image:         string | null,
  source_name:   string,
  published_at:  timestamp,
  fetched_at:    timestamp   // server timestamp of the sync run that wrote/refreshed this doc
}
```

### Phase 2: Fair Price & Travel Alert Map
- Integrated via official `google_maps_flutter` plugin.
- **Backend Data:** Fetch from Cloud Firestore (`partner_locations`, `alert_zones`).
- **Out of Scope for MVP:** NO local Admin Panel / CMS. Data populated directly in Firebase
  Console or via the seed scripts (`tools/seed_firestore.js`, `lib/tools/seed_data.dart`).
  A web-based CMS to manage this data is planned post-MVP — see **Phase 5** below.
- **Partner images:** `partner_locations.image_url` currently points to free-to-use
  stock photos (Pexels License — free for commercial use, no attribution required),
  used as generic per-type placeholders (hotel/restaurant/transport) until real partner
  photos exist. Rendered via `_PartnerThumbnail` in `map_screen.dart` with an icon
  fallback if the URL is empty or fails to load.
- **Interaction:** Tapping pins shows Custom Pop-up with Partner Name, Rating, Verified Badge.
- Color zones: green (safe) / amber (caution) / red (danger) overlays on map.

### Phase 2b: Home Travel Alerts (GNews) ✅ IMPLEMENTED
- Shows Thailand travel-disruption news (floods, storms, fires, road closures, major
  accidents, etc.) on the Home tab and a full list screen — sourced from the
  [GNews API](https://gnews.io/docs/v4) (`https://gnews.io/api/v4/search`).
- **Server-side shared cache — the Flutter app never calls GNews directly.** A scheduled
  Firebase Cloud Function, `syncTravelAlerts` (`functions/index.js`, `asia-southeast1`),
  polls GNews **every 15 minutes**, filters results to items mentioning
  "Thailand"/"Bangkok" plus a travel-disruption keyword, and upserts them into the
  `travel_alerts_cache` Firestore collection (doc id = md5 of the article url, so re-runs
  update in place instead of duplicating; docs no longer returned by GNews are deleted
  from the collection in the same batch).
  - **Why:** `shared_preferences` is per-device local storage. With a client-side fetch,
    every device runs its own refresh timer against the *same* GNews API key, so total
    request volume scales with install count and can blow through the 100
    requests/day free-tier quota. Fetching once server-side and having every client read
    the same Firestore collection keeps usage constant (24h × 4/hr = 96 requests/day)
    regardless of user count.
  - The Flutter app (`lib/features/home/services/travel_alert_service.dart`) just does a
    plain Firestore read of `travel_alerts_cache`, ordered by `published_at desc` — see
    `FirestoreService` for the equivalent pattern used by the Map/Scanner collections.
  - The GNews API key is **not** embedded in the client. It's stored as a Firebase
    Functions secret (`GNEWS_API_KEY`), set once via
    `firebase functions:secrets:set GNEWS_API_KEY` and injected only into the Cloud
    Function's execution environment.
  - **Deploying/updating the function:** `cd functions && npm install`, then
    `firebase deploy --only functions:syncTravelAlerts` from the repo root. Requires the
    Firebase project to be on the **Blaze (pay-as-you-go) plan** — Cloud Functions cannot
    deploy on the free Spark plan even though actual usage stays inside Blaze's free
    tier. Check the plan at
    `https://console.firebase.google.com/project/thaishield-ai-790eb/usage`.
  - Keep `SEARCH_TERMS` in `functions/index.js` in sync with the (client-side, display-only)
    category-keyword list in `lib/features/home/models/travel_alert.dart` if either changes.

### Phase 3: AI Price Scanner ✅ IMPLEMENTED
- Native camera (`image_picker`) captures a photo. Two-stage matching:
  1. **OCR first** (`google_mlkit_text_recognition`, on-device): reads printed text/numbers
     from menus or price tags, matches against `price_standards` in Firestore, calculates
     variance %.
  2. **Gemini Vision fallback**: if OCR finds no readable text or no matching item (e.g. the
     photo is just a plate of food with no visible price), the photo is sent to Gemini
     (`gemini-2.5-flash`, see `lib/features/scanner/services/gemini_vision_service.dart`)
     to identify the dish name. The device's current GPS coordinates are passed along only
     as disambiguation context for regional dish names — never stored, never used for
     location-specific pricing (the `price_standards` schema has no location dimension).
     The identified name is looked up in `price_standards` and shown as a **typical price
     range only** (no variance bar, since no price was actually scanned from the image).
- **Visual Output:** Colored variance bar (e.g., "+15% from standard price") for OCR matches;
  a plain typical-range card with an "AI Identified" badge for Gemini-Vision matches.
- **CRITICAL LEGAL BOUNDARY:** Output UI **MUST NEVER** display specific restaurant names,
  exact locations, or brands — applies to both the OCR and Gemini Vision paths. Show only
  pure statistical variance/range to avoid defamation issues.

### Phase 4: AI Voice SOS (STT to TTS Mode) ✅ IMPLEMENTED
- Tap and hold to record speech → Native STT → Gemini translation → Thai TTS playback.
- **Multi-language STT:** STT locale follows the user's app language (`LocaleProvider`).
  Mapping: `en→en_US`, `zh→zh_CN`, `ko→ko_KR`, `ru→ru_RU`, `ja→ja_JP`, `th→th_TH`.
  The Gemini prompt is dynamically constructed as "The tourist said in [Language]: …"
  so Gemini always receives the correct source language regardless of what was spoken.
- **PROMPT COMPLIANCE:** Returned Thai string MUST always end with polite particles ("ครับ" or "ค่ะ").
- **Model:** `gemini-3.5-flash` via HTTP REST (`--dart-define=GEMINI_API_KEY`). Endpoint: `v1beta`. (`gemini-2.5-flash` and all 2.x variants return 404 "not available to new users" for this API key — `gemini-3.5-flash` is the confirmed working model as of 2026-07).
- **Emergency numbers** (`profile_screen.dart`): dialed with `LaunchMode.externalApplication`
  to force the phone dialer — prevents extra digits or browser intercept on iOS/Android.

### Phase 5: Web CMS (Quoted — Post-MVP)
A separate web-based admin dashboard for non-technical staff to manage Firestore content
without touching the Firebase Console directly. Quoted 20/07/2026 as its own 5-item,
**9,000 THB** engagement — separate from the 45,000 THB app budget in Section 2's header
(software development only — excludes ongoing domain/cloud hosting costs), paid in 3
installments (30% on system init, 40% on data-management + mapping completion, 30% on
verification/delivery/deploy):
- **Stack (confirmed, not just illustrative):** **Next.js 14** + **Firebase Admin SDK**,
  deployed to **Firebase Hosting**.
- **Admin login:** the CMS has its own login screen for staff, using **Firebase
  Authentication** (Admin Auth). This is a property of the *separate* CMS project only —
  it does not contradict Section 3's "Firebase Auth completely omitted for MVP," which
  refers to the Flutter app, not this admin site.
- **Manages:** `price_standards` (CRUD, multi-language fields, image preview),
  `partner_locations` (CRUD, **upload real partner photos to Firebase Storage** —
  not hotlinked third-party stock photos — replacing today's Pexels placeholders),
  `alert_zones` (CRUD via an **interactive polygon editor built on the Google Maps
  API**, for drawing/editing the advisory-area boundary points instead of hand-editing
  GeoPoint arrays).
- **Out of scope for the Flutter app itself:** this is a *separate* project. The Flutter
  app already reads generically from Firestore via `FirestoreService`, so it needs **no
  changes** to consume data written by the CMS — the CMS just needs to write to the same
  collections/fields documented above.
- **Auth & write access to Firestore data:** Firestore rules (`firestore.rules`)
  currently allow public **read-only** access to `price_standards`/`partner_locations`/
  `alert_zones` and deny all client writes (see Section 6 below). The CMS must write
  either via the **Firebase Admin SDK with a service account** (bypasses security
  rules — simplest) or via an **authenticated admin role** added to the rules. Never
  weaken the public rules to allow open writes from the Flutter app to make this work.
- **Pre-launch QA step:** the quote's testing phase includes a legal-wording review pass
  — any copy entered/edited through the CMS (e.g. `alert_zones` descriptions) must still
  follow the Section 7 wording rules, since CMS staff can write free-text fields that
  bypass the Flutter app's own copy.

## 3. Strict Out of Scope (DO NOT CODE)
- NO User Registration / Authentication / Login screens (Firebase Auth completely omitted for MVP).
- NO User Scan History logs or personal profile tracking databases.
- NO Rating Forms or Community comment inputs.
- NO Live Chat or Premium Support layout simulators.

## 4. Firebase Setup Instructions
```bash
# 1. Install FlutterFire CLI (run once)
dart pub global activate flutterfire_cli

# 2. Install Firebase CLI (run once)
npm install -g firebase-tools

# 3. Login to Firebase
firebase login

# 4. Configure project (generates lib/firebase_options.dart)
flutterfire configure
```
After running `flutterfire configure`, select the Firebase project and enable Android + iOS platforms.

### Cloud Functions (GNews sync — see Phase 2b)
```bash
# 1. Install function dependencies (once, and after editing functions/package.json)
cd functions && npm install

# 2. Set the GNews key as a Functions secret (once, or when the key rotates)
firebase functions:secrets:set GNEWS_API_KEY

# 3. Deploy just this function
firebase deploy --only functions:syncTravelAlerts
```
Requires the Firebase project to be on the **Blaze plan** (Section 2b explains why).

## 5. Useful Project Commands
- Run app:          `flutter run`
- Fetch plugins:    `flutter pub get`
- Clean caches:     `flutter clean`
- Analyze code:     `flutter analyze lib/`
- Android APK:      `flutter build apk --split-per-abi --release`
- Android Bundle:   `flutter build appbundle --release`
- iOS (CI only):    handled by Codemagic pipeline

## 6. Firestore Security Rules

Rules live in `firestore.rules` in this repo (kept as a backup/reference — the live
rules are edited directly in Firebase Console → Firestore Database → Rules, the same
place all collection data is populated, since there is no CMS yet per Phase 5 above).

- `price_standards`, `partner_locations`, `alert_zones` are **public read, no write**
  (`allow read: if true; allow write: if false;`). The app has no Firebase Auth, so reads
  must stay open for the Map and Scanner features to work at all.
- **Never use Firebase's default "test mode" rule** (`allow read, write: if request.time <
  timestamp.date(...)`) for anything beyond initial local testing — it has an expiry date
  and **silently denies all reads once it passes**, breaking the Map and Scanner with no
  code change required to trigger it. This has happened once already; if Map/Scanner
  suddenly fail in production with no related code or dependency change, check the Rules
  tab in Firebase Console first before suspecting Google Maps API keys/billing.
- Any future authenticated write access (e.g. for the Phase 5 CMS) must be scoped to that
  specific use case — don't broaden the public rule to allow writes from the Flutter app.
- `travel_alerts_cache` (Phase 2b) is also **public read, no write** — it's written only
  by the `syncTravelAlerts` Cloud Function via the Admin SDK, which bypasses these rules
  entirely, so the `allow write: if false` here is solely to block writes from clients.

## 7. Legal Safe Wording Guide (MANDATORY — applies to ALL user-facing text)

ThaiShield AI displays pricing and travel-safety information. To minimize legal risk
(defamation, accusation, or damages claims against shops, individuals, or areas),
**all UI copy, alerts, scan results, and map screens MUST use neutral, statistical,
informational wording** — never accusatory or judgmental language.

This applies to: widget text, ARB localization strings, Firestore seed data
(`tools/seed_firestore.js`, `lib/tools/seed_data.dart`), push notifications, and any
AI-generated (Gemini/OpenAI) responses shown to users.

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
- **Never** display shop names, logos, or other shop-identifying info on the price-scan
  results screen (see Phase 3 boundary above) — show only statistical variance.
- **Never** use directly accusatory words: Scam, Fraud, Cheating, Overcharge, Rip-off,
  Dangerous, Unsafe, Blacklist, Exploitation, etc.
- Frame all price commentary statistically: "Average Price", "Price Variation",
  "Above Typical Range", "Significant Price Variation".
- Every screen that shows price analysis (Scanner results, Map partner panel, etc.)
  **MUST display a disclaimer**:
  - **EN:** "This information is generated from statistical and community-based data
    and is intended for informational purposes only. Actual prices may vary."
  - **TH:** "ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น
    ราคาจริงอาจแตกต่างกันได้"

The app's goal is to **inform** tourists to help them make decisions — never to **judge
or accuse** any specific shop, person, or area. Apply this standard to every new
feature and copy change.

## 8. UI Theme & Color Guide (MANDATORY — applies to every screen, current and future)

ThaiShield AI uses one consistent dark-green "ranger" theme for the top header and the
bottom navigation bar on every screen, so the user never sees a jarring color seam
between the header, the page body, and the bottom nav. This was fixed once already
(bottom nav was tinted navy `0xFF0D1B2A` while headers used green `0xFF0A1810` —
do not reintroduce that mismatch).

### Core palette

| Role | Color | Hex |
|---|---|---|
| Header background / bottom nav tint (primary brand color) | dark green | `#0A1810` |
| Page body background | light grey | `#F3F5F7` |
| Card / heading text on white cards | dark navy | `#0D1B2A` |
| Accent gold (brand title, active highlights) | gold | `#FFB300` |
| Accent blue (info, scan, profile icons) | sky blue | `#4FC3F7` |
| Accent green (safe/verified/success) | green | `#2E7D32` |
| Accent red (alerts/SOS/danger) | red | `#EF5350` / `#D32F2F` |
| Secondary muted text | grey | `#90A4AE` |

### Rules
- Any screen with a top header bar **must** use `#0A1810` as the header background
  (see `_buildHeader` in `home_tab.dart` / `profile_screen.dart` for the canonical
  pattern: logo + "ThaiShield AI" gold title + page title + subtitle).
- The bottom navigation bar (`lib/features/home/widgets/main_bottom_nav.dart`) tints
  its skyline background image with the **same** `#0A1810` green — never navy
  (`#0D1B2A`) or any other color. If the header color ever changes, update the bottom
  nav tint in the same change.
- `#0D1B2A` (dark navy) is reserved for **text/icons on white cards**, not for any
  full-screen or header background — keep these two dark colors visually distinct in
  their roles.
- Page body background outside of cards should default to `#F3F5F7` unless a screen's
  approved mockup specifies otherwise (e.g. Smart Map's white toolbar is an
  intentional, already-approved exception — don't "fix" it without being asked).
- When building a new screen or redesigning an existing one (Scan, SOS, Map, etc.),
  default to this same header + bottom-nav treatment unless the user's mockup
  explicitly shows something different.
