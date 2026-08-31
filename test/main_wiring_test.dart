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
      expect(
        source.contains('PremiumProvider(billing:'),
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

    test('entitlements are still loaded before the first frame', () {
      // Not billing, but the same class of silent breakage: without this the
      // app renders one frame as a free user for someone who has paid.
      expect(source.contains('await premiumProvider.load()'), isTrue);
    });
  });
}
