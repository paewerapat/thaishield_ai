import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one line that connects the app to the stores.
///
/// 🚨 Why a source-scanning test rather than a behavioural one:
/// `PremiumProvider` takes its [BillingService] as an optional argument that
/// defaults to null, because constructing the real one opens a platform
/// channel and would break every widget test that builds a screen. The cost of
/// that choice is that **forgetting to pass it is completely silent** — the
/// app compiles, analyze is clean, all tests pass, and every purchase and
/// restore answers "billing is not available in this build" to every user
/// forever. There is no runtime assertion that could catch it, because a
/// provider with no billing is exactly what the tests construct on purpose.
///
/// This is the same shape as the paywall's legal links: the mechanism was
/// covered and the wiring was not.
void main() {
  group('main.dart wiring', () {
    late String source;

    setUp(() => source = File('lib/main.dart').readAsStringSync());

    test('the premium provider is given a billing service', () {
      // A regex, not a substring: the constructor call became multi-line on
      // 2026-09-01 when `activityLog:` was added beside it, and the literal
      // 'PremiumProvider(billing:' stopped matching a file that was still
      // correct. Matching across the newline keeps the property this test
      // exists for — the argument is present — without pinning the formatting
      // dart format chooses.
      expect(
        RegExp(r'PremiumProvider\(\s*billing:').hasMatch(source),
        isTrue,
        reason:
            'lib/main.dart builds PremiumProvider without `billing:`. Purchases '
            'and restores will silently answer notAvailableYet for every user.',
      );
    });

    test('it is the real store implementation, not a placeholder', () {
      expect(
        source.contains('InAppPurchaseBilling()'),
        isTrue,
        reason: 'main.dart no longer constructs the real billing service',
      );
    });

    test('the premium provider is given an activity log', () {
      // Same silent-failure shape as `billing:`, and the same reason for a
      // source-scanning test: reporting is fire-and-forget and swallows its
      // own errors, so a provider built without this argument behaves exactly
      // like one whose writes are all failing. Nothing a user or a screen can
      // see tells them apart. What breaks is the client's admin — App Users
      // and Transactions stay empty forever, and the honest reading of an
      // empty page is "nobody is using the app".
      expect(
        source.contains('activityLog:'),
        isTrue,
        reason:
            'lib/main.dart builds PremiumProvider without `activityLog:`. The '
            'CMS will report zero users and zero purchases, indefinitely.',
      );
    });

    test('it is the real Firestore log, not a placeholder', () {
      expect(source.contains('FirestoreActivityLog()'), isTrue);
    });

    test('the premium provider is given a receipt verifier', () {
      // The third argument with the same silent-failure shape, and the worst
      // of the three to lose: with no verifier the app is back to trusting
      // whatever the device says about a purchase, which `EntitlementRepository`
      // is explicit is not a security boundary — and the subscription goes back
      // to a rolling one-period guess instead of the store's real renewal date.
      // Nothing on screen changes, so only a test can notice.
      expect(
        source.contains('verifier:'),
        isTrue,
        reason: 'lib/main.dart builds PremiumProvider without `verifier:`, so '
            'no purchase is ever checked with Play or Apple.',
      );
      expect(
        source.contains('CloudFunctionVerifier.instance'),
        isTrue,
        reason: 'main.dart no longer wires the real verifier',
      );
    });

    test('the launch itself is recorded', () {
      // Without this call the only rows ever written are for people who reach
      // the paywall. "เริ่มใช้งานเมื่อไหร่" would then mean "first bought",
      // and every free user would be invisible.
      expect(
        source.contains('premiumProvider.recordUsage('),
        isTrue,
        reason:
            'main.dart no longer records the launch, so free users never '
            'appear in the CMS at all.',
      );
    });

    test('the language choice is reported when it is made', () {
      // 🚨 `main()` reports the locale BEFORE the language screen has run, so
      // the first launch always sends null. Without a second report at the
      // moment of choosing, the CMS's "Lang" column is blank for every fresh
      // install until the app is opened again — and anyone who installs, looks
      // once and never returns is recorded with no language at all. That
      // biases the one column answering "which languages do tourists pick"
      // toward returning users, which is a wrong answer rather than a missing
      // one. Found on a real row on 2026-09-02.
      expect(
        source.contains('onLanguageSelected') &&
            // Whitespace-tolerant: the call in `main()` is wrapped across
            // lines by dart format, so a literal match finds only one of the
            // two and the test fails against correct code.
            RegExp(r'recordUsage\(\s*locale:').allMatches(source).length >= 2,
        isTrue,
        reason:
            'main.dart reports the locale only once, before the language '
            'screen. Fresh installs will have no language recorded.',
      );
    });

    test('entitlements are still loaded before the first frame', () {
      // Not billing, but the same class of silent breakage: without this the
      // app renders one frame as a free user for someone who has paid.
      expect(source.contains('await premiumProvider.load()'), isTrue);
    });

    test('there is exactly one localization system, and it is app_text', () {
      // 🚨 There were two until 2026-09-12, and only one of them worked.
      // `l10n.yaml` + `generate: true` produced `lib/l10n/app_localizations*.dart`
      // from six .arb files, but `AppLocalizations.delegate` was never added to
      // `localizationsDelegates` and nothing ever called
      // `AppLocalizations.of(context)`. Every string the app actually shows
      // comes from `app_text.dart`. The ARB half was not a bug — it was worse,
      // a trap: a key added there compiled cleanly, generated cleanly, and had
      // no effect, silently. Deleted rather than wired, because wiring it would
      // have meant two tables for one job.
      //
      // The three Global* delegates below are `flutter_localizations`, which is
      // still needed and must not be removed with it — they are what translate
      // the OS-supplied strings (the back-button tooltip, date pickers) and
      // what stops a non-English locale logging "unsupported locale".
      expect(
        Directory('lib/l10n').existsSync(),
        isFalse,
        reason: 'lib/l10n is back. If a second localization system is genuinely '
            'wanted, wire its delegate in main.dart in the same commit — an '
            'unwired one silently swallows every key added to it.',
      );
      expect(File('l10n.yaml').existsSync(), isFalse,
          reason: 'l10n.yaml is back but nothing reads the output');
      expect(
        File('pubspec.yaml').readAsStringSync().contains('generate: true'),
        isFalse,
        reason: 'generate: true regenerates the ARB path on every pub get',
      );
      expect(source.contains('AppLocalizations'), isFalse,
          reason: 'main.dart references AppLocalizations, which no longer exists');

      // The half that stays.
      for (final delegate in const [
        'GlobalMaterialLocalizations.delegate',
        'GlobalWidgetsLocalizations.delegate',
        'GlobalCupertinoLocalizations.delegate',
      ]) {
        expect(source.contains(delegate), isTrue,
            reason: '$delegate was removed along with the ARB path. It is '
                'flutter_localizations, not the generated code, and without it '
                'every non-English locale falls back for OS-supplied strings.');
      }
    });

    test('main.dart supports exactly the six languages app_text serves', () {
      // The list in main.dart and the columns in app_text.dart are the two
      // halves of the same promise. A locale in one and not the other is a
      // language the app offers and cannot draw, or draws and cannot be set to.
      for (final language in const ['th', 'en', 'zh', 'ko', 'ru', 'ja']) {
        expect(source.contains("Locale('$language')"), isTrue,
            reason: '$language is missing from main.dart supportedLocales');
      }
      final declared = RegExp(r"Locale\('(\w+)'\)")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, hasLength(6),
          reason: 'main.dart declares $declared, but the app ships six '
              'languages — add or remove the matching app_text column too');
    });
  });
}
