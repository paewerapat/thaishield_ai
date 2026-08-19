/// Third-party API keys. These are read-only/free-tier keys used directly
/// from the client, consistent with how the Maps API keys are embedded in
/// this MVP (no backend proxy in scope).
///
/// The news feed is the one exception: its key lives server-side only, as a
/// Firebase Functions secret (`NEWSDATA_API_KEY`) used by the scheduled
/// `syncTravelAlerts` Cloud Function (see `functions/index.js`). The app
/// never calls newsdata.io directly, so no client-side key exists here.
class ApiKeys {
  /// Google Cloud Speech-to-Text, used by the SOS screen:
  ///   flutter run --dart-define=GCS_STT_KEY=your_key_here
  ///
  /// Restrict it to the Speech-to-Text API in Cloud Console. Note this only
  /// works because SOS calls the **v1** endpoint — v2 (and therefore Chirp)
  /// rejects API keys outright and needs a service account, which would mean
  /// a backend proxy. See `_transcribeWithGCS` in `sos_screen.dart`.
  static const String speechToText = String.fromEnvironment('GCS_STT_KEY');

  /// Get a free key at https://aistudio.google.com/apikey. Unlike the keys
  /// above, this one is bound to a service account (GitHub push protection
  /// flags it as a high-severity secret), so it is injected at build time
  /// instead of being committed to source:
  ///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  /// In Codemagic, set GEMINI_API_KEY as a secure environment variable and
  /// pass --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY in the build script.
  static const String gemini = String.fromEnvironment('GEMINI_API_KEY');

  /// Google **Routes API** key, used by the Route Suggestion preview
  /// (Phase 2B task 2.4):
  ///   flutter run --dart-define=ROUTES_API_KEY=your_key_here
  ///
  /// Kept separate from the Maps SDK keys committed in `AndroidManifest.xml`
  /// and `AppDelegate.swift` on purpose. Those are *SDK* keys, which Google
  /// lets you lock to an app signature / bundle id, so embedding them is safe.
  /// Routes is a **web service** — Google does not honour Android/iOS
  /// application restrictions on it, so the only restriction available is
  /// "API restriction: Routes API" plus a quota cap. Restrict it to Routes and
  /// set a daily quota in Cloud Console; a leaked unrestricted key bills to
  /// this project. See the note in `route_service.dart` about cost.
  static const String googleRoutes = String.fromEnvironment('ROUTES_API_KEY');
}
