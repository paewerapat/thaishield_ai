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
- **Model:** `gemini-2.5-flash-001` (versioned — use the `001` suffix, not the bare alias which is restricted for new API keys) via HTTP REST (`--dart-define=GEMINI_API_KEY`). Endpoint: `v1` (not `v1beta`).
- **Emergency numbers** (`profile_screen.dart`): dialed with `LaunchMode.externalApplication`
  to force the phone dialer — prevents extra digits or browser intercept on iOS/Android.

### Phase 5: Web CMS (Planned — Post-MVP)
A separate web-based admin dashboard for non-technical staff to manage Firestore content
without touching the Firebase Console directly:
- **Manages:** `price_standards` (add/edit dishes + price ranges), `partner_locations`
  (add/edit partners, **upload real partner photos** to replace today's Pexels
  placeholders), `alert_zones` (add/edit advisory areas + polygons).
- **Out of scope for the Flutter app itself:** this is a *separate* project (e.g. a small
  Next.js or Firebase-Hosted admin site). The Flutter app already reads generically from
  Firestore via `FirestoreService`, so it needs **no changes** to consume data written by
  a future CMS — the CMS just needs to write to the same collections/fields documented
  above.
- **Auth & write access:** Firestore rules (`firestore.rules`) currently allow public
  **read-only** access to `price_standards`/`partner_locations`/`alert_zones` and deny
  all client writes (see Section 6 below). The CMS must write either via the **Firebase
  Admin SDK with a service account** (bypasses security rules — simplest) or via an
  **authenticated admin role** added to the rules. Never weaken the public rules to allow
  open writes from the Flutter app to make this work.
- **Image storage:** once built, the CMS should upload partner photos to **Firebase
  Storage** (not hotlinked third-party stock photos) so partners own their own images.

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
