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

### Phase 1: Language Onboarding
- Screen on first-launch to choose language: EN, ZH, RU, KO, JA.
- Save global selection in Local App State using `shared_preferences`.
- Automatically localize app labels based on this local state.

### Phase 2: Fair Price & Travel Alert Map
- Integrated via `google_maps_flash` or official `google_maps_flutter` plugin.
- **Backend Data:** Fetch Mockup Data from Cloud Firestore (approx. 10 verified partner nodes, 2-3 dynamic pricing zones).
- **Out of Scope:** NO local Admin Panel / CMS for managing shops. All data is populated directly in the Firebase Console by the dev.
- **Interaction:** Tapping pins displays a Custom Pop-up showing Partner Name, Average Rating, and a Verified Badge.

### Phase 3: AI Price Scanner
- Activate native camera inside the app to capture text/numbers from menus or transit signs.
- **Mockup Logic:** Process the scanned string numbers, calculate the variance percentage against the standard average price stored in Firestore.
- **Visual Output:** Show a colored variance bar (e.g., "+15% from standard price").
- **CRITICAL LEGAL BOUNDARY:** The output UI **MUST NEVER** display specific restaurant names, exact locations, or brands. Show only pure statistical variance to avoid defamation issues.

### Phase 4: AI Voice SOS (STT to TTS Mode)
- Tap and hold/press to record English speech -> Convert to string via Native Speech-to-Text (STT).
- Call external AI API (Gemini or OpenAI API) via a structured JSON payload.
- **PROMPT COMPLIANCE:** The AI translation prompt must force the returned Thai string to be highly polite and **ALWAYS** end with polite particles ("ครับ" or "ค่ะ").
- Convert the returned Thai string into audio out loud using Native Text-to-Speech (TTS).

## 3. Strict Out of Scope (DO NOT CODE)
- NO User Registration / Authentication / Login screens (Firebase Auth is completely omitted for this MVP).
- NO User Scan History logs or personal profile tracking databases.
- NO Rating Forms or Community comment inputs.
- NO Live Chat or Premium Support layout simulators.

## 4. Useful Project Commands
- Run app: `flutter run`
- Fetch plugins: `flutter pub get`
- Clean caches: `flutter clean`
- Android build: `flutter build apk --split-per-abi` or `flutter build appbundle`