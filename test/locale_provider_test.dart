import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/providers/locale_provider.dart';

/// The onboarding screen's whole job is to be shown once. These pin the case
/// that made it show forever.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocaleProvider', () {
    test('records English even though English is the starting value', () async {
      // The bug this exists for: `_locale` starts as English, so choosing
      // English matched the current value, hit an early return, and never
      // reached storage. hasSelectedLocale stayed false and the picker came
      // back on every launch — but only for people who chose English, which is
      // why it survived every test and every manual pass.
      final provider = LocaleProvider();
      expect(await provider.hasSelectedLocale(), isFalse);

      await provider.setLocale(const Locale('en'));

      expect(
        await provider.hasSelectedLocale(),
        isTrue,
        reason: 'choosing English did not persist, so onboarding will repeat',
      );
    });

    test('records every other language too', () async {
      for (final code in ['th', 'zh', 'ko', 'ru', 'ja']) {
        SharedPreferences.setMockInitialValues({});
        final provider = LocaleProvider();
        await provider.setLocale(Locale(code));
        expect(await provider.hasSelectedLocale(), isTrue, reason: code);
      }
    });

    test('reads the saved choice back on the next launch', () async {
      final first = LocaleProvider();
      await first.setLocale(const Locale('ru'));

      final second = LocaleProvider();
      await second.loadSavedLocale();
      expect(second.locale.languageCode, 'ru');
    });

    test('re-picking the same language is not a no-op for storage', () async {
      final provider = LocaleProvider();
      await provider.setLocale(const Locale('ja'));
      // Setting it again must still leave the choice recorded, whatever the
      // provider decides about notifying listeners.
      await provider.setLocale(const Locale('ja'));
      expect(await provider.hasSelectedLocale(), isTrue);
      expect(provider.locale.languageCode, 'ja');
    });
  });
}
