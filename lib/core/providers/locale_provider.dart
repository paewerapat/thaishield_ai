import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'selected_locale';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null) {
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  /// Records the choice, and rebuilds only if it actually changed.
  ///
  /// 🚨 **The write must not be skipped when the value matches.** [_locale]
  /// starts as English, so `setLocale(Locale('en'))` from the onboarding
  /// screen used to hit an early `return` and never reach
  /// `SharedPreferences` — which left [hasSelectedLocale] false forever and
  /// showed the language picker again on every launch, but only for the people
  /// who chose English. Found by on-device QA 2026-08-30; it had been there
  /// since the first phase, because every test and every manual pass happened
  /// to pick Thai.
  ///
  /// Notifying is what is conditional now, not persisting.
  Future<void> setLocale(Locale locale) async {
    final changed = _locale != locale;
    _locale = locale;
    if (changed) notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  Future<bool> hasSelectedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kLocaleKey);
  }
}
