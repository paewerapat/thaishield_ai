import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has agreed to the app sending their photo (price scanner)
/// or voice recording (SOS) to Google's AI services for processing.
///
/// ## Why this exists
///
/// Apple rejected build 1.1.31 on 2026-09-16 under guidelines 5.1.1 / 5.1.2:
/// the app hands user content to a third-party AI service — Gemini for the
/// scanner and the SOS translation, Cloud Speech-to-Text for the SOS
/// transcript — without asking first. The OS camera and microphone prompts do
/// not count: they cover the *capture*, not where the capture is sent.
///
/// So both features ask once, in the app's own words, before the first use
/// (`ensureAiConsent` in `lib/core/widgets/ai_consent_sheet.dart`), and the
/// answer is kept here. The Profile tab carries a switch that shows the same
/// answer and lets the user withdraw it; a withdrawn consent makes the sheet
/// come back on the next scan or SOS press rather than silently blocking.
///
/// 🚨 **Ask before capture, not after.** Asking after the photo is taken means
/// a declined user has already produced a file that was going to be uploaded,
/// which is the situation the guideline is about. The scanner therefore asks
/// before opening the camera, and SOS before starting the recorder.
///
/// This is on-device state only — a `SharedPreferences` flag, like the locale.
/// Nothing about the choice is sent anywhere.
class AiConsentStore extends ChangeNotifier {
  AiConsentStore([this._preferences]);

  /// The app-wide instance. Screens read this; tests build their own.
  static final AiConsentStore instance = AiConsentStore();

  static const _key = 'ai_processing_consent';
  static const _atKey = 'ai_processing_consent_at';

  SharedPreferences? _preferences;
  bool? _granted;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// False until [load] has run, so a screen that renders before then treats
  /// the user as not yet asked — which is the safe direction.
  bool get isGranted => _granted ?? false;

  bool get isLoaded => _granted != null;

  Future<bool> load() async {
    final prefs = await _prefs();
    _granted = prefs.getBool(_key) ?? false;
    notifyListeners();
    return _granted!;
  }

  /// Records agreement and when it was given.
  Future<void> grant() async {
    final prefs = await _prefs();
    await prefs.setBool(_key, true);
    await prefs.setString(_atKey, DateTime.now().toUtc().toIso8601String());
    _granted = true;
    notifyListeners();
  }

  /// Withdraws agreement. The next scan or SOS press asks again.
  Future<void> revoke() async {
    final prefs = await _prefs();
    await prefs.setBool(_key, false);
    await prefs.remove(_atKey);
    _granted = false;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _granted = null;
    _preferences = null;
  }
}
