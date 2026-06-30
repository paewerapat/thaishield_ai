/// Third-party API keys. These are read-only/free-tier keys used directly
/// from the client, consistent with how the Maps API keys are embedded in
/// this MVP (no backend proxy in scope).
class ApiKeys {
  /// Get a free key at https://gnews.io after signing up.
  static const String gnews = '20407ffb0abe26126aee9088178dbebb';

  /// Get a free key at https://aistudio.google.com/apikey. Unlike the keys
  /// above, this one is bound to a service account (GitHub push protection
  /// flags it as a high-severity secret), so it is injected at build time
  /// instead of being committed to source:
  ///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  /// In Codemagic, set GEMINI_API_KEY as a secure environment variable and
  /// pass --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY in the build script.
  static const String gemini = String.fromEnvironment('GEMINI_API_KEY');
}
