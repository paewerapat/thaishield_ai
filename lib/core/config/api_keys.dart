/// Third-party API keys. These are read-only/free-tier keys used directly
/// from the client, consistent with how the Maps API keys are embedded in
/// this MVP (no backend proxy in scope).
///
/// GNews is the one exception: its key lives server-side only, as a
/// Firebase Functions secret (`GNEWS_API_KEY`) used by the scheduled
/// `syncTravelAlerts` Cloud Function (see `functions/index.js`). The app
/// never calls GNews directly, so no client-side key exists here.
class ApiKeys {
  /// Get a free key at https://aistudio.google.com/apikey. Unlike the keys
  /// above, this one is bound to a service account (GitHub push protection
  /// flags it as a high-severity secret), so it is injected at build time
  /// instead of being committed to source:
  ///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  /// In Codemagic, set GEMINI_API_KEY as a secure environment variable and
  /// pass --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY in the build script.
  static const String gemini = String.fromEnvironment('GEMINI_API_KEY');
}
