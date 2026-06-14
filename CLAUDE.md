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
- **Out of Scope:** NO local Admin Panel / CMS. All data populated directly in Firebase Console.
- **Interaction:** Tapping pins shows Custom Pop-up with Partner Name, Rating, Verified Badge.
- Color zones: green (safe) / amber (caution) / red (danger) overlays on map.

### Phase 3: AI Price Scanner
- Activate native camera to capture text/numbers from menus or transit signs.
- **Mockup Logic:** Match scanned text against `price_standards` in Firestore, calculate variance %.
- **Visual Output:** Colored variance bar (e.g., "+15% from standard price").
- **CRITICAL LEGAL BOUNDARY:** Output UI **MUST NEVER** display specific restaurant names, exact locations, or brands. Show only pure statistical variance to avoid defamation issues.

### Phase 4: AI Voice SOS (STT to TTS Mode)
- Tap and hold to record English speech → Native STT → string.
- Call Gemini or OpenAI API via structured JSON payload.
- **PROMPT COMPLIANCE:** Returned Thai string MUST always end with polite particles ("ครับ" or "ค่ะ").
- Convert returned Thai string to audio via Native TTS.

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

## 6. Legal Safe Wording Guide (MANDATORY — applies to ALL user-facing text)

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
