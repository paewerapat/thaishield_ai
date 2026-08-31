import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';

/// Can a user actually get to the plans screen?
///
/// 🚨 **The bug this exists for.** A fresh install is granted the 3-day trial
/// automatically on first launch. Profile's "view plans" button was wrapped in
/// `if (!active)`, and it was the app's only way in. So for the first three
/// days: every premium gate passed, no feature was ever locked, and the plans
/// screen could not be opened at all. A new user saw an app indistinguishable
/// from the free version, and someone who wanted to subscribe early could not.
///
/// The client reported it on 2026-08-31 as "the app still looks the same",
/// which is exactly right and was not a missing feature.
///
/// Nothing behavioural could catch this: the paywall worked, the trial worked,
/// the gates worked. What was broken was that the two correct behaviours,
/// combined, hid the third. So these read the source — the same approach as
/// `main_wiring_test.dart`, and for the same reason.
class _NullRepository implements EntitlementRepository {
  @override
  Future<void> save(Entitlement entitlement) async {}
  @override
  Future<Entitlement?> fetch(String purchaseId) async => null;
  @override
  Future<Entitlement?> restoreBest(Iterable<String> ids) async => null;
}

void main() {
  group('the plans screen is reachable', () {
    test('Profile does not hide the button while access is active', () {
      final source =
          File('lib/features/profile/screens/profile_screen.dart')
              .readAsStringSync();

      // The guard sat immediately before the TextButton that opens the paywall.
      final guardIndex = source.indexOf('if (!active) ...[');
      expect(
        guardIndex,
        -1,
        reason:
            'profile_screen.dart hides the plans button while Premium is '
            'active. The trial makes every new install active on first launch, '
            'so this hides it from exactly the people who have not paid yet.',
      );
    });

    test('the map screen carries its own way in', () {
      // The design poster puts a Premium card at the top right of this screen.
      // Profile alone is three taps away, and was hidden during the trial.
      final source =
          File('lib/features/map/screens/map_screen.dart').readAsStringSync();

      expect(source.contains('_PremiumEntry()'), isTrue,
          reason: 'the map header no longer offers a way to the plans screen');
      expect(source.contains('class _PremiumEntry'), isTrue);
    });

    test('the map entry is not gated on being unsubscribed either', () {
      final source =
          File('lib/features/map/screens/map_screen.dart').readAsStringSync();
      final start = source.indexOf('class _PremiumEntry');
      final body = source.substring(start, source.indexOf('\n}', start));

      // A `!isPremium` check here would reintroduce the same hole one screen
      // over: invisible for the whole trial, which is when it matters most.
      expect(
        body.contains('isPremium'),
        isFalse,
        reason: 'the map premium entry is conditional on entitlement again',
      );
    });
  });

  group('why it was invisible', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a fresh install is Premium from the first launch', () {
      // Not a defect on its own — it is the agreed 3-day trial. It is recorded
      // here because it is the half of the bug that is easy to forget, and
      // because anyone testing a build sees an unlocked app and reasonably
      // concludes nothing was built.
      return () async {
        final provider = PremiumProvider(repository: _NullRepository());
        await provider.load();
        expect(provider.isPremium, isFalse);

        await provider.startTrialIfEligible();

        expect(provider.isPremium, isTrue);
        expect(provider.isOnTrial, isTrue);
      }();
    });
  });
}
