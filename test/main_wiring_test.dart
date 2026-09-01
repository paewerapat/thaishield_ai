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

    test('entitlements are still loaded before the first frame', () {
      // Not billing, but the same class of silent breakage: without this the
      // app renders one frame as a free user for someone who has paid.
      expect(source.contains('await premiumProvider.load()'), isTrue);
    });
  });
}
