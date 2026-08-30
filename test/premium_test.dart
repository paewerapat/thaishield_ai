// Phase 2B task 2.5 — paywall, entitlement and feature-gating unit tests.
//
// The gates themselves are one-line calls into `ensurePremium`; what is worth
// pinning is everything they depend on — when an entitlement counts as active,
// what survives a round trip through storage, how much the free tier sees, and
// that the app ships locked rather than unlocked.
//
// Reworked 2026-08-22 for the two one-time passes that replaced the three
// subscription plans. The interesting new surface is that the app now owns the
// clock and the trial, because the stores own neither for a consumable.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/core/models/alert_zone.dart';
import 'package:thaishield_ai/core/models/partner_category.dart';
import 'package:thaishield_ai/core/models/partner_location.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/models/premium_feature.dart';
import 'package:thaishield_ai/features/premium/models/premium_plan.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_store.dart';
import 'package:thaishield_ai/features/radar/models/radar_result.dart';

const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

const _premiumKeys = [
  'premium_title',
  'premium_subtitle',
  'premium_feature_radar',
  'premium_feature_filter',
  'premium_feature_route',
  'premium_benefits_title',
  'premium_plan_weekly',
  'premium_plan_monthly',
  'premium_period_weekly',
  'premium_period_monthly',
  'premium_trial_note',
  'premium_status_trial',
  'premium_badge_recommended',
  'premium_price_note',
  'premium_cta',
  'premium_store_unavailable',
  'premium_restore',
  'premium_restore_none',
  'premium_platform_note',
  'premium_legal_note',
  'premium_status_free_title',
  'premium_status_free_subtitle',
  'premium_status_active_title',
  'premium_status_expires',
  'premium_status_qa',
  'premium_upgrade_action',
  'premium_locked_results',
  'premium_locked_action',
];

PartnerLocation _partner(String id) => PartnerLocation(
      id: id,
      name: 'Partner $id',
      lat: 13.72,
      lng: 100.52,
      type: 'restaurant',
      rating: 4,
      isVerified: true,
      priceTier: 'fair',
      imageUrl: '',
    );

RadarResult _resultWith(int count) {
  return RadarResult(
    center: const LatLng(13.72, 100.52),
    radiusKm: 1,
    entries: [
      for (var i = 0; i < count; i++)
        RadarPartnerEntry(partner: _partner('$i'), distanceKm: i * 0.1),
    ],
  );
}

/// Stands in for Firestore so the restore path can be exercised without a
/// network or an emulator. Only the two methods `PremiumProvider` calls are
/// overridden; the rest of the class is never reached in these tests.
class _FakeRepository implements EntitlementRepository {
  final saved = <Entitlement>[];
  final byId = <String, Entitlement>{};

  @override
  Future<void> save(Entitlement entitlement) async {
    saved.add(entitlement);
    final id = entitlement.purchaseId;
    if (id != null) byId[id] = entitlement;
  }

  @override
  Future<Entitlement?> fetch(String purchaseId) async => byId[purchaseId];

  @override
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async {
    Entitlement? best;
    for (final id in purchaseIds) {
      final found = byId[id];
      if (found == null) continue;
      if (best == null || found.expiresAt.isAfter(best.expiresAt)) best = found;
    }
    return best;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Entitlement.isActiveAt', () {
    final now = DateTime.utc(2026, 8, 19, 12);

    test('a pass is active until its expiry and not after', () {
      final entitlement = Entitlement(
        plan: PremiumPlan.monthly,
        source: EntitlementSource.store,
        expiresAt: now.add(const Duration(days: 1)),
      );

      expect(entitlement.isActiveAt(now), isTrue);
      expect(entitlement.isActiveAt(now.add(const Duration(days: 2))), isFalse);
    });

    test('an entitlement expiring exactly now is over', () {
      final entitlement = Entitlement(
        plan: PremiumPlan.weekly,
        source: EntitlementSource.store,
        expiresAt: now,
      );
      expect(entitlement.isActiveAt(now), isFalse);
    });

    test('the trial runs for exactly the advertised three days', () {
      // The stores cannot run this for us, so the app owns the clock — and the
      // length is a promise printed on the paywall.
      final trial = Entitlement.trial(startedAt: now);

      expect(trial.expiresAt, now.add(const Duration(days: 3)));
      expect(trial.isTrial, isTrue);
      expect(trial.plan, isNull);
      expect(
        trial.isActiveAt(now.add(const Duration(days: 2, hours: 23))),
        isTrue,
      );
      expect(trial.isActiveAt(now.add(const Duration(days: 3))), isFalse);
    });

    test('remaining time never goes negative', () {
      final entitlement = Entitlement(
        plan: PremiumPlan.weekly,
        source: EntitlementSource.store,
        expiresAt: now,
      );

      expect(
        entitlement.remainingAt(now.add(const Duration(days: 5))),
        Duration.zero,
      );
      expect(
        entitlement.remainingAt(now.subtract(const Duration(days: 2))),
        const Duration(days: 2),
      );
    });
  });

  group('Entitlement serialization', () {
    test('round-trips a purchased pass, including the transaction id', () {
      // The purchase id is what the Firestore copy is filed under, so losing it
      // in a round trip would quietly break restore on a new device.
      final original = Entitlement(
        plan: PremiumPlan.weekly,
        source: EntitlementSource.store,
        expiresAt: DateTime.utc(2027, 1, 2, 3, 4, 5),
        purchaseId: 'GPA.1234-5678',
      );

      final restored = Entitlement.fromJson(original.toJson())!;

      expect(restored.plan, PremiumPlan.weekly);
      expect(restored.source, EntitlementSource.store);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.purchaseId, 'GPA.1234-5678');
    });

    test('round-trips a trial', () {
      final original = Entitlement.trial(startedAt: DateTime.utc(2026, 8, 22));
      final restored = Entitlement.fromJson(original.toJson())!;

      expect(restored.isTrial, isTrue);
      expect(restored.plan, isNull);
      expect(restored.expiresAt, original.expiresAt);
    });

    test('keeps the QA source distinguishable from a purchase', () {
      final original = Entitlement(
        plan: PremiumPlan.monthly,
        source: EntitlementSource.qaOverride,
        expiresAt: DateTime.utc(2027),
      );

      expect(
        Entitlement.fromJson(original.toJson())!.source,
        EntitlementSource.qaOverride,
      );
    });

    test('unreadable records drop to free rather than granting access', () {
      // Every one of these would otherwise be a way to hand out access by
      // writing to a preferences file.
      expect(Entitlement.fromJson({}), isNull);
      expect(
        Entitlement.fromJson({'product_id': 'not_a_plan', 'source': 'store'}),
        isNull,
      );
      expect(
        Entitlement.fromJson({
          'product_id': PremiumPlan.monthly.productId,
          'source': 'something_else',
        }),
        isNull,
      );
      expect(
        Entitlement.fromJson({
          'product_id': PremiumPlan.monthly.productId,
          'source': 'store',
          'expires_at': 'not a date',
        }),
        isNull,
      );
    });

    test('a record stored without an expiry is rejected', () {
      // Nothing may claim to last forever — the lifetime plan was cancelled on
      // 2026-08-22, so a truncated record must not become an unbounded grant.
      expect(
        Entitlement.fromJson({
          'product_id': PremiumPlan.monthly.productId,
          'source': 'store',
          'expires_at': null,
        }),
        isNull,
      );
    });

    test('a purchase claiming to be a trial, or the reverse, is rejected', () {
      // A trial names no product; a purchase must name a known one. Anything
      // in between is a record we cannot reason about, and guessing means
      // either charging nobody or unlocking everybody.
      expect(
        Entitlement.fromJson({
          'product_id': PremiumPlan.monthly.productId,
          'source': 'trial',
          'expires_at': DateTime.utc(2027).toIso8601String(),
        }),
        isNull,
      );
      expect(
        Entitlement.fromJson({
          'source': 'store',
          'expires_at': DateTime.utc(2027).toIso8601String(),
        }),
        isNull,
      );
    });

    test('a record written by an older build does not survive', () {
      // The yearly and lifetime products no longer exist. A preferences file
      // left over from a build that had them must drop to free.
      expect(
        Entitlement.fromJson({
          'product_id': 'thaishield_premium_lifetime',
          'source': 'store',
          'expires_at': DateTime.utc(2099).toIso8601String(),
        }),
        isNull,
      );
    });
  });

  group('PremiumPlan', () {
    test('product ids are unique and stable', () {
      final ids = PremiumPlan.values.map((p) => p.productId).toSet();
      expect(ids.length, PremiumPlan.values.length);
      // These strings have to match the products created in Play Console and
      // App Store Connect, so a rename here is a breaking change.
      // `_2weeks` is retired, not renamed. That id was documented as a
      // consumable, and an id that once meant one product type must never be
      // pointed at another — a product's type is irreversible in both stores.
      expect(PremiumPlan.weekly.productId, 'thaishield_premium_weekly');
      expect(PremiumPlan.monthly.productId, 'thaishield_premium_monthly');
    });

    test('both plans are auto-renewing subscriptions', () {
      // Client decision 2026-08-30, replacing the one-time passes of
      // 2026-08-22. This assertion is the reason the flip was cheap: call
      // sites asked `isSubscription` instead of assuming, so there were no
      // hardcoded beliefs to hunt down.
      //
      // 🚨 If this ever flips again, every product already created in either
      // store is the wrong type and cannot be converted — only replaced under
      // a new id, at the cost of a fresh review.
      for (final plan in PremiumPlan.values) {
        expect(plan.isSubscription, isTrue, reason: plan.name);
        expect(plan.duration, greaterThan(Duration.zero), reason: plan.name);
      }
    });

    test('the billing periods are ones the stores actually sell', () {
      // Neither store offers a 14-day period — the choices are 1 week, 1, 2, 3
      // and 6 months, and a year. That gap is what forced the original
      // one-time-pass design, and it is why the short plan is weekly rather
      // than a fortnight. A duration that is not on this list cannot be created
      // as a subscription at all, so it is worth failing here rather than in
      // the console.
      const sellable = [
        Duration(days: 7),
        Duration(days: 30),
        Duration(days: 60),
        Duration(days: 90),
        Duration(days: 180),
        Duration(days: 365),
      ];
      for (final plan in PremiumPlan.values) {
        expect(sellable, contains(plan.duration), reason: plan.name);
      }
    });

    test('the plan lengths and prices match what the client set', () {
      expect(PremiumPlan.weekly.duration, const Duration(days: 7));
      expect(PremiumPlan.monthly.duration, const Duration(days: 30));
      expect(PremiumPlan.weekly.priceUsd, 3.5);
      expect(PremiumPlan.monthly.priceUsd, 10);
      expect(PremiumPlan.trialDuration, const Duration(days: 3));
    });

    test('fromProductId resolves what the stores will send back', () {
      for (final plan in PremiumPlan.values) {
        expect(PremiumPlan.fromProductId(plan.productId), plan);
      }
      expect(PremiumPlan.fromProductId('unknown'), isNull);
      expect(PremiumPlan.fromProductId('thaishield_premium_yearly'), isNull);
      expect(PremiumPlan.fromProductId('thaishield_premium_lifetime'), isNull);
      // The retired one, kept here so nobody quietly revives it.
      expect(PremiumPlan.fromProductId('thaishield_premium_2weeks'), isNull);
    });
  });

  group('RadarResult.take', () {
    test('keeps the nearest entries, in order', () {
      final trimmed = _resultWith(9).take(3);

      expect(trimmed.count, 3);
      expect(trimmed.entries.first.id, 'partner_0');
      expect(trimmed.entries.last.id, 'partner_2');
      expect(trimmed.center, const LatLng(13.72, 100.52));
      expect(trimmed.radiusKm, 1);
    });

    test('is a no-op when the limit is not reached', () {
      final result = _resultWith(2);
      expect(identical(result.take(3), result), isTrue);
      expect(identical(result.take(2), result), isTrue);
    });

    test('handles a negative limit without throwing', () {
      expect(_resultWith(4).take(-1).count, 0);
    });
  });

  group('PremiumProvider', () {
    late _FakeRepository repository;

    PremiumProvider build() => PremiumProvider(repository: repository);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = _FakeRepository();
      await EntitlementStore.instance.clear();
    });

    test('ships locked — no override flag in a plain build', () {
      // `flutter test` passes no --dart-define, which is the shape of a
      // release build. If this ever passes, the app ships unlocked.
      expect(PremiumProvider.qaOverrideFlag, isFalse);
    });

    test('starts free with nothing stored', () async {
      final provider = build();
      await provider.load();

      expect(provider.isLoaded, isTrue);
      expect(provider.isPremium, isFalse);
      expect(provider.entitlement, isNull);
      expect(provider.isQaUnlocked, isFalse);
      expect(provider.isOnTrial, isFalse);
      expect(provider.daysRemaining, isNull);
    });

    test('a QA unlock grants access and survives a reload', () async {
      final provider = build();
      await provider.load();
      await provider.qaUnlock(PremiumPlan.monthly);

      expect(provider.isPremium, isTrue);
      expect(provider.isQaUnlocked, isTrue);
      expect(provider.entitlement!.source, EntitlementSource.qaOverride);

      final reloaded = build();
      await reloaded.load();
      expect(reloaded.isPremium, isTrue);
      expect(reloaded.isQaUnlocked, isTrue);
    });

    test('a QA unlock is never filed in Firestore', () async {
      // It is not a purchase, and a record of it would be indistinguishable
      // from one on any other device that read it back.
      final provider = build();
      await provider.load();
      await provider.qaUnlock(PremiumPlan.monthly);

      expect(repository.saved, isEmpty);
    });

    test('a QA lock clears it again', () async {
      final provider = build();
      await provider.load();
      await provider.qaUnlock(PremiumPlan.weekly);
      expect(provider.isPremium, isTrue);

      await provider.qaLock();
      expect(provider.isPremium, isFalse);
      expect(await EntitlementStore.instance.read(), isNull);
    });

    test('notifies listeners so gates rebuild', () async {
      final provider = build();
      await provider.load();

      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.qaUnlock(PremiumPlan.monthly);
      await provider.qaLock();

      expect(notifications, 2);
    });

    test('an expired entitlement does not unlock anything', () async {
      await EntitlementStore.instance.write(
        Entitlement(
          plan: PremiumPlan.monthly,
          source: EntitlementSource.store,
          expiresAt: DateTime.utc(2020),
        ),
      );

      final provider = build();
      await provider.load();

      expect(provider.entitlement, isNotNull);
      expect(provider.isPremium, isFalse);
      expect(provider.daysRemaining, 0);
    });

    test('purchase and restore report that billing is not live yet', () async {
      // Phase 2C task 2.8 replaces these two bodies; the paywall already
      // handles every value of the enum.
      final provider = build();
      expect(
        await provider.purchase(PremiumPlan.monthly),
        StoreOutcome.notAvailableYet,
      );
      expect(await provider.restore(), StoreOutcome.notAvailableYet);
    });

    test('the free radar allowance is a small positive number', () {
      expect(PremiumProvider.freeRadarResultLimit, greaterThan(0));
      expect(PremiumProvider.freeRadarResultLimit, lessThan(10));
    });

    group('trial', () {
      test('a new install gets three days and is unlocked', () async {
        final provider = build();
        await provider.load();

        expect(await provider.startTrialIfEligible(), isTrue);
        expect(provider.isPremium, isTrue);
        expect(provider.isOnTrial, isTrue);
        expect(provider.daysRemaining, 3);
        expect(provider.entitlement!.source, EntitlementSource.trial);
      });

      test('is granted once, even after the trial has run out', () async {
        final provider = build();
        await provider.load();
        await provider.startTrialIfEligible();

        // Expire it the way time would, then try again on a fresh provider —
        // the flag has to outlive the entitlement or the trial is unlimited.
        await EntitlementStore.instance.clear();
        final second = build();
        await second.load();

        expect(await second.startTrialIfEligible(), isFalse);
        expect(second.isPremium, isFalse);
      });

      test('never overwrites a pass someone paid for', () async {
        final provider = build();
        await provider.load();
        await provider.grantPurchase(
          plan: PremiumPlan.monthly,
          purchaseId: 'GPA.paid',
        );

        expect(await provider.startTrialIfEligible(), isFalse);
        expect(provider.entitlement!.source, EntitlementSource.store);
        expect(provider.isOnTrial, isFalse);
      });

      test('is not filed in Firestore', () async {
        final provider = build();
        await provider.load();
        await provider.startTrialIfEligible();

        expect(repository.saved, isEmpty);
      });
    });

    group('grantPurchase', () {
      test('dates the pass from the purchase and files it', () async {
        final provider = build();
        await provider.load();

        final at = DateTime.utc(2026, 9, 1, 8);
        await provider.grantPurchase(
          plan: PremiumPlan.weekly,
          purchaseId: 'GPA.abc',
          purchasedAt: at,
        );

        final entitlement = provider.entitlement!;
        expect(entitlement.expiresAt, at.add(const Duration(days: 7)));
        expect(entitlement.purchaseId, 'GPA.abc');
        expect(entitlement.source, EntitlementSource.store);
        expect(repository.saved.single.purchaseId, 'GPA.abc');
      });

      test('survives a reload from the local cache alone', () async {
        final provider = build();
        await provider.load();
        await provider.grantPurchase(
          plan: PremiumPlan.monthly,
          purchaseId: 'GPA.abc',
        );

        final reloaded = build();
        await reloaded.load();

        expect(reloaded.isPremium, isTrue);
        expect(reloaded.entitlement!.purchaseId, 'GPA.abc');
      });
    });

    group('restoreFromPurchaseIds', () {
      test('recovers a pass bought on another device', () async {
        // The whole reason the Firestore copy exists: a consumable is not
        // replayed with its remaining days by either store.
        final expiry = DateTime.utc(2027);
        await repository.save(
          Entitlement(
            plan: PremiumPlan.monthly,
            source: EntitlementSource.store,
            expiresAt: expiry,
            purchaseId: 'GPA.other-phone',
          ),
        );

        final provider = build();
        await provider.load();
        expect(provider.isPremium, isFalse);

        expect(
          await provider.restoreFromPurchaseIds(['GPA.other-phone']),
          StoreOutcome.success,
        );
        expect(provider.isPremium, isTrue);
        expect(provider.entitlement!.expiresAt, expiry);
      });

      test('keeps the furthest expiry when several passes are found', () async {
        for (final entry in {
          'GPA.a': DateTime.utc(2026, 12),
          'GPA.b': DateTime.utc(2027, 6),
        }.entries) {
          await repository.save(
            Entitlement(
              plan: PremiumPlan.weekly,
              source: EntitlementSource.store,
              expiresAt: entry.value,
              purchaseId: entry.key,
            ),
          );
        }

        final provider = build();
        await provider.load();
        await provider.restoreFromPurchaseIds(['GPA.a', 'GPA.b']);

        expect(provider.entitlement!.expiresAt, DateTime.utc(2027, 6));
      });

      test('never shortens a pass already running on this device', () async {
        final provider = build();
        await provider.load();
        await provider.grantPurchase(
          plan: PremiumPlan.monthly,
          purchaseId: 'GPA.local',
          purchasedAt: DateTime.utc(2026, 9),
        );
        final before = provider.entitlement!.expiresAt;

        await repository.save(
          Entitlement(
            plan: PremiumPlan.weekly,
            source: EntitlementSource.store,
            expiresAt: DateTime.utc(2026, 8, 1),
            purchaseId: 'GPA.older',
          ),
        );

        expect(
          await provider.restoreFromPurchaseIds(['GPA.older']),
          StoreOutcome.success,
        );
        expect(provider.entitlement!.expiresAt, before);
      });

      test('says so when the store has nothing for this account', () async {
        final provider = build();
        await provider.load();

        expect(
          await provider.restoreFromPurchaseIds([]),
          StoreOutcome.nothingToRestore,
        );
        expect(
          await provider.restoreFromPurchaseIds(['GPA.unknown']),
          StoreOutcome.nothingToRestore,
        );
        expect(provider.isPremium, isFalse);
      });
    });
  });

  group('paywall copy', () {
    test('every premium string exists in all six languages', () {
      for (final key in _premiumKeys) {
        final entry = appStrings[key];
        expect(entry, isNotNull, reason: 'missing key: $key');
        for (final language in _languages) {
          expect(
            entry![language]?.trim(),
            isNotEmpty,
            reason: 'missing or empty $language for $key',
          );
        }
      }
    });

    test('every gated feature has a headline the paywall can show', () {
      for (final feature in PremiumFeature.values) {
        final entry = appStrings[feature.headlineKey];
        expect(
          entry,
          isNotNull,
          reason: '${feature.name} points at a missing key',
        );
        for (final language in _languages) {
          expect(entry![language]?.trim(), isNotEmpty);
        }
      }
    });

    test('every plan has a title and a period in all six languages', () {
      for (final plan in PremiumPlan.values) {
        for (final key in [plan.titleKey, plan.periodKey]) {
          for (final language in _languages) {
            expect(
              appStrings[key]?[language]?.trim(),
              isNotEmpty,
              reason: 'missing $language for $key',
            );
          }
        }
      }
    });

    test('placeholders survive translation', () {
      for (final language in _languages) {
        expect(
          appStrings['premium_status_expires']![language],
          contains('{date}'),
        );
        expect(
          appStrings['premium_status_trial']![language],
          contains('{days}'),
        );
        expect(
          appStrings['premium_locked_results']![language],
          contains('{count}'),
        );
      }
    });

    test('English copy obeys the §10 wording rules', () {
      // §10 names paywall copy explicitly. The temptation on a paywall is to
      // sell safety — "stay safe", "avoid dangerous areas" — which is both a
      // claim the app cannot make and the judgement §10 forbids.
      const banned = [
        'scam',
        'fraud',
        'cheat',
        'overcharge',
        'rip-off',
        'dangerous',
        'unsafe',
        'blacklist',
        'avoid',
        'protect',
        'stay safe',
        'guarantee',
      ];

      for (final key in _premiumKeys) {
        final english = appStrings[key]!['en']!.toLowerCase();
        for (final word in banned) {
          expect(
            english.contains(word),
            isFalse,
            reason: '$key uses banned wording "$word": $english',
          );
        }
      }
    });

    test('the store rules the app has to satisfy are stated in the copy', () {
      final platform = appStrings['premium_platform_note']!['en']!.toLowerCase();
      // Entitlements do not cross platforms, and this is the one thing users
      // reliably complain about after paying, so it must be said up front.
      expect(platform, contains('android'));
      expect(platform, contains('ios'));
    });

    test('restore is promised on both platforms, because it now works', () {
      // Inverted 2026-08-30. The old assertion pinned the opposite: a one-time
      // pass is a consumable, Apple never replays consumables, and so the
      // remaining days could not be recovered on a new iPhone. That was an
      // accepted limitation on 2026-08-23 and the copy had to disclose it.
      //
      // Subscriptions restore on iOS and Android alike, so the limitation is
      // gone — and a note still warning about it would now be scaring users off
      // something that works. What survives is the part that is still true:
      // entitlements do not cross between the two platforms, because that is a
      // property of the store account rather than of the product type.
      for (final language in _languages) {
        final text = appStrings['premium_platform_note']![language]!;
        expect(
          text.contains('Android') || text.contains('android'),
          isTrue,
          reason: '$language must still say the purchase does not cross platforms',
        );
      }

      final english = appStrings['premium_platform_note']!['en']!.toLowerCase();
      expect(english, contains('does not transfer between android and ios'));
      expect(
        english.contains('does not restore'),
        isFalse,
        reason: 'the iOS restore limitation no longer exists and must not be implied',
      );
    });

    test('the copy discloses the renewal, because there is one now', () {
      // Inverted 2026-08-30. This used to assert the opposite — that no string
      // promised a renewal — because both products were one-time passes and a
      // renewal claim would have been a billing disclosure the app could not
      // honour. Now the products renew, and the omission is the violation:
      // both stores reject a subscription screen that does not say it renews,
      // and a user who is charged again without being told asks for a refund.
      final legal = appStrings['premium_legal_note']!['en']!.toLowerCase();
      expect(legal, contains('auto-renewing'));
      expect(legal, contains('charged automatically'));
      // Where to cancel, which is the store and not this app.
      expect(legal, contains('cancel'));
      expect(legal, contains('store'));
      // And that cancelling keeps the period already paid for — the part users
      // are most often surprised by, and the one that generates refunds when
      // it is left out.
      expect(legal, contains('already paid'));

      expect(
        legal.contains('single payment') || legal.contains('nothing renews'),
        isFalse,
        reason: 'the one-time-pass wording survived the switch to subscriptions',
      );

      // The five non-English columns get checked for substance, not just for
      // being non-empty. A blank check would pass a paragraph that says
      // anything at all, and this is the string both stores review — a
      // translation that quietly drops the renewal is the failure this test
      // exists for, and it looks exactly like a filled-in field.
      //
      // Each language names the word its own disclosure has to contain. These
      // are the renewal and the cancellation, the two facts a reviewer looks
      // for and the two a user complains about when they are missing.
      const mustSay = {
        'th': ['ต่ออายุอัตโนมัติ', 'ยกเลิก'],
        'zh': ['自动续订', '取消'],
        'ko': ['자동 갱신', '해지'],
        'ru': ['автоматическ', 'отмен'],
        'ja': ['自動更新', '解約'],
      };

      for (final language in _languages) {
        final text = appStrings['premium_legal_note']![language]!;
        expect(
          text.trim(),
          isNotEmpty,
          reason: 'the renewal disclosure is missing in $language',
        );
        for (final phrase in mustSay[language] ?? const <String>[]) {
          expect(
            text.contains(phrase),
            isTrue,
            reason: 'the $language disclosure never says "$phrase"',
          );
        }
      }
    });

    test('the trial copy says what happens when it ends', () {
      // A trial that quietly stops is a support ticket; a trial that appears to
      // start a charge is a refund request. The English has to rule both out.
      final note = appStrings['premium_trial_note']!['en']!.toLowerCase();
      expect(note, contains('3 days free'));
      expect(note, contains('free version'));
      expect(note, contains('nothing is charged'));
    });

    test('the price note points at the store, not at the figure on screen', () {
      // `PremiumPlan.priceUsd` is a USD figure compiled into the app. What the
      // user is actually charged is the store's localised, tax-inclusive
      // price, so the screen must not present its own number as the deal.
      final note = appStrings['premium_price_note']!['en']!.toLowerCase();
      expect(note, contains('google play'));
      expect(note, contains('app store'));
    });

    test('no copy survives for a plan that no longer exists', () {
      // Leaving these behind is how a cancelled plan reappears on a screen.
      for (final key in [
        'premium_plan_yearly',
        'premium_plan_lifetime',
        'premium_period_yearly',
        'premium_period_lifetime',
      ]) {
        expect(appStrings[key], isNull, reason: '$key should have been removed');
      }
    });
  });

  group('alert zone model is untouched by gating', () {
    test('radar entries still group by risk level', () {
      // Cheap guard that trimming the list for the free tier did not disturb
      // how entries are bucketed.
      final zone = AlertZone(
        id: 'z1',
        name: 'Test',
        centerLat: 13.72,
        centerLng: 100.52,
        radiusKm: 1,
        riskLevel: 'danger',
        descriptionEn: '',
        descriptionTh: '',
        polygon: const [],
      );
      final entry = RadarZoneEntry(zone: zone, distanceKm: 0, isInside: true);
      expect(entry.group, RadarGroup.zoneDanger);
    });
  });
}
