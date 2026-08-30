import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/providers/locale_provider.dart';
import 'package:thaishield_ai/features/onboarding/screens/language_selection_screen.dart';

/// The onboarding screen's whole job is to be shown once. These pin the case
/// that made it show forever.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  _screenTests();

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

    test('re-picking the same language still writes', () async {
      // 🚨 The first version of this test started the provider at its English
      // default and called setLocale('ja') twice. The *first* call already
      // differed from the current value, so it persisted under the old buggy
      // code too — the test passed against the exact bug its name describes.
      //
      // Wiping storage between the two calls is what forces the second one to
      // travel the `_locale == locale` path and still reach SharedPreferences.
      final provider = LocaleProvider();
      await provider.setLocale(const Locale('ja'));

      SharedPreferences.setMockInitialValues({});
      expect(await provider.hasSelectedLocale(), isFalse);

      await provider.setLocale(const Locale('ja'));

      expect(
        await provider.hasSelectedLocale(),
        isTrue,
        reason: 'setting the language it already holds skipped the write',
      );
      expect(provider.locale.languageCode, 'ja');
    });
  });
}

/// The provider tests above prove the storage rule. These prove the onboarding
/// screen actually uses it.
///
/// 🚨 A QA agent deleted the `setLocale` call from
/// `LanguageSelectionScreen._select` — leaving the language picker able to do
/// nothing but dismiss itself — and every test in the repo stayed green. The
/// provider was covered; the one caller that matters was not. That is the same
/// shape as the paywall's legal-link test: coverage of the mechanism is not
/// coverage of the wiring.
void _screenTests() {
  group('LanguageSelectionScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// The list of languages is a `ListView`, so on a phone-sized test surface
    /// the last rows are never built and `find.text` cannot see them. That is a
    /// property of the test window, not the screen.
    Future<LocaleProvider> pumpPicker(
      WidgetTester tester, {
      VoidCallback? onSelected,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = LocaleProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>.value(
          value: provider,
          child: MaterialApp(
            home: LanguageSelectionScreen(
              onLanguageSelected: onSelected ?? () {},
            ),
          ),
        ),
      );
      return provider;
    }

    testWidgets('tapping a language records it, not just dismisses the screen',
        (tester) async {
      final provider = await pumpPicker(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(provider.locale.languageCode, 'en');
      expect(
        await provider.hasSelectedLocale(),
        isTrue,
        reason: 'the picker dismissed without recording the choice',
      );
    });

    testWidgets('every one of the six offered languages is wired up',
        (tester) async {
      const labels = {
        'ไทย / Thai': 'th',
        'English': 'en',
        '中文 / Chinese': 'zh',
        '한국어 / Korean': 'ko',
        'Русский / Russian': 'ru',
        '日本語 / Japanese': 'ja',
      };

      for (final entry in labels.entries) {
        SharedPreferences.setMockInitialValues({});
        final provider = await pumpPicker(tester);

        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();

        expect(provider.locale.languageCode, entry.value);
        expect(await provider.hasSelectedLocale(), isTrue, reason: entry.key);
      }
    });

    testWidgets('the callback still fires, so onboarding advances',
        (tester) async {
      var advanced = false;
      final provider = await pumpPicker(tester, onSelected: () => advanced = true);

      await tester.tap(find.text('日本語 / Japanese'));
      await tester.pumpAndSettle();

      expect(advanced, isTrue);
      expect(provider.locale.languageCode, 'ja');
    });
  });
}
