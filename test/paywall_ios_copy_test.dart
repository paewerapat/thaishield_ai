import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/screens/paywall_screen.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';

/// App Review, 2026-09-16, guideline 2.3.10: the paywall on an iPhone named
/// Google Play and Android. Every store-naming string now has an `_ios` twin
/// that names only the App Store and Apple ID, and `storeText` picks it.
///
/// These tests pin both halves: the iOS copy never names the other platform,
/// and it still carries every disclosure the base copy is tested for in
/// `premium_test.dart` — a rewrite that dropped "auto-renewing" to lose the
/// word "Google" would be a different rejection.
const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

/// The keys whose base copy names a store, and therefore must have a twin.
const _storeKeys = [
  'premium_price_note',
  'premium_store_unavailable',
  'premium_platform_note',
  'premium_legal_note',
];

const _bannedOnIos = ['google play', 'play store', 'android', 'google'];

class _NullRepository implements EntitlementRepository {
  @override
  Future<void> save(Entitlement entitlement) async {}

  @override
  Future<Entitlement?> fetch(String purchaseId) async => null;

  @override
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async => null;
}

Widget _host(Widget child, {String language = 'en'}) {
  return ChangeNotifierProvider<PremiumProvider>.value(
    value: PremiumProvider(repository: _NullRepository()),
    child: MaterialApp(
      locale: Locale(language),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th'),
        Locale('en'),
        Locale('zh'),
        Locale('ko'),
        Locale('ru'),
        Locale('ja'),
      ],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('every string that names a store has an iOS twin', () {
    test('the twin exists in all six languages', () {
      for (final key in _storeKeys) {
        final twin = appStrings['${key}_ios'];
        expect(twin, isNotNull, reason: '${key}_ios is missing');
        for (final language in _languages) {
          expect(twin![language]?.trim(), isNotEmpty,
              reason: '${key}_ios has no $language text');
        }
      }
    });

    test('no other base key names Google Play or Android without a twin', () {
      // The scan that found the four. If a fifth string ever names the other
      // platform, it needs a twin too — or it is the next rejection.
      for (final entry in appStrings.entries) {
        if (entry.key.endsWith('_ios')) continue;
        final mentions = entry.value.values.any((text) {
          final lower = text.toLowerCase();
          return lower.contains('google play') ||
              lower.contains('play store') ||
              lower.contains('android');
        });
        if (!mentions) continue;
        expect(appStrings.containsKey('${entry.key}_ios'), isTrue,
            reason: '${entry.key} names Google Play or Android on iOS too — '
                'add ${entry.key}_ios and read it through storeText');
      }
    });

    test('the iOS twins never name the other platform', () {
      for (final key in _storeKeys) {
        for (final language in _languages) {
          final lower = appStrings['${key}_ios']![language]!.toLowerCase();
          for (final word in _bannedOnIos) {
            expect(lower.contains(word), isFalse,
                reason: '${key}_ios/$language says "$word"');
          }
        }
      }
    });

    test('the iOS twins name the store and the account instead', () {
      for (final language in _languages) {
        expect(appStrings['premium_price_note_ios']![language],
            contains('App Store'), reason: language);
        expect(appStrings['premium_store_unavailable_ios']![language],
            contains('Apple ID'), reason: language);
        expect(appStrings['premium_platform_note_ios']![language],
            contains('Apple ID'), reason: language);
        expect(appStrings['premium_legal_note_ios']![language],
            contains('Apple ID'), reason: language);
      }
    });

    test('the iOS legal note keeps every disclosure the base note is tested for',
        () {
      final legal = appStrings['premium_legal_note_ios']!['en']!.toLowerCase();
      expect(legal, contains('auto-renewing'));
      expect(legal, contains('charged automatically'));
      expect(legal, contains('cancel'));
      expect(legal, contains('app store'));
      expect(legal, contains('already paid'));
      expect(legal, contains('charged once'));
      expect(legal, contains('never renews'));
      expect(legal, contains('nothing to cancel'));

      const mustSay = {
        'th': ['ต่ออายุอัตโนมัติ', 'ยกเลิก'],
        'zh': ['自动续订', '取消'],
        'ko': ['자동 갱신', '해지'],
        'ru': ['автоматическ', 'отмен'],
        'ja': ['自動更新', '解約'],
      };
      for (final language in _languages) {
        final text = appStrings['premium_legal_note_ios']![language]!;
        for (final phrase in mustSay[language] ?? const <String>[]) {
          expect(text.contains(phrase), isTrue,
              reason: 'the $language iOS disclosure never says "$phrase"');
        }
      }
    });

    test('the iOS platform note still says the pass is not restored', () {
      // The limitation is real on iPhone (StoreKit never replays a consumed
      // purchase); dropping the word "Android" must not drop the warning.
      for (final language in _languages) {
        expect(appStrings['premium_platform_note_ios']![language],
            contains('14'), reason: language);
      }
      final english =
          appStrings['premium_platform_note_ios']!['en']!.toLowerCase();
      expect(english, contains('cannot be restored'));
      expect(english, contains('loses the remaining days'));
    });
  });

  group('storeText', () {
    testWidgets('picks the iOS twin on an iPhone and the base copy elsewhere',
        (tester) async {
      late String onIos;
      late String onAndroid;

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        onIos = storeText(context, 'premium_platform_note');
        return const SizedBox();
      })));

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        onAndroid = storeText(context, 'premium_platform_note');
        return const SizedBox();
      })));

      debugDefaultTargetPlatformOverride = null;
      expect(onIos, appTextIn('en', 'premium_platform_note_ios'));
      expect(onAndroid, appTextIn('en', 'premium_platform_note'));
      expect(onIos.toLowerCase(), isNot(contains('android')));
    });

    testWidgets('a key with no twin falls through to appText on iOS',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late String text;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        text = storeText(context, 'premium_cta');
        return const SizedBox();
      })));
      debugDefaultTargetPlatformOverride = null;
      expect(text, appTextIn('en', 'premium_cta'));
    });
  });

  group('the paywall on an iPhone', () {
    testWidgets('shows no Google Play or Android anywhere on the screen',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_host(const PaywallScreen()));
      await tester.pumpAndSettle();

      // Scroll the small print into the tree the way a reviewer would.
      final note = appTextIn('en', 'premium_legal_note_ios');
      await tester.scrollUntilVisible(find.text(note), 200);
      await tester.pumpAndSettle();
      // Reset before the assertions: the binding verifies this variable is
      // untouched at the end of the body, before tearDown would run.
      debugDefaultTargetPlatformOverride = null;

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase())
          .toList();
      for (final text in texts) {
        for (final word in _bannedOnIos) {
          expect(text.contains(word), isFalse,
              reason: 'the iPhone paywall shows "$word": $text');
        }
      }
      expect(find.text(note), findsOneWidget);
    });
  });
}
