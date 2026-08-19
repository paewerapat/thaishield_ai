// Phase 2B task 2.5 — paywall, entitlement and feature-gating unit tests.
//
// The gates themselves are one-line calls into `ensurePremium`; what is worth
// pinning is everything they depend on — when an entitlement counts as active,
// what survives a round trip through storage, how much the free tier sees, and
// that the app ships locked rather than unlocked.

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
  'premium_plan_monthly',
  'premium_plan_yearly',
  'premium_plan_lifetime',
  'premium_period_monthly',
  'premium_period_yearly',
  'premium_period_lifetime',
  'premium_badge_recommended',
  'premium_price_note',
  'premium_cta',
  'premium_store_unavailable',
  'premium_restore',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Entitlement.isActiveAt', () {
    final now = DateTime.utc(2026, 8, 19, 12);

    test('a lifetime purchase never expires', () {
      const entitlement = Entitlement.lifetime(EntitlementSource.store);
      expect(entitlement.isActiveAt(now), isTrue);
      expect(entitlement.isActiveAt(DateTime.utc(2099)), isTrue);
    });

    test('a subscription is active until its expiry and not after', () {
      final entitlement = Entitlement(
        plan: PremiumPlan.monthly,
        source: EntitlementSource.store,
        expiresAt: now.add(const Duration(days: 1)),
      );

      expect(entitlement.isActiveAt(now), isTrue);
      expect(
        entitlement.isActiveAt(now.add(const Duration(days: 2))),
        isFalse,
      );
    });

    test('an entitlement expiring exactly now is over', () {
      final entitlement = Entitlement(
        plan: PremiumPlan.yearly,
        source: EntitlementSource.store,
        expiresAt: now,
      );
      expect(entitlement.isActiveAt(now), isFalse);
    });
  });

  group('Entitlement serialization', () {
    test('round-trips a subscription', () {
      final original = Entitlement(
        plan: PremiumPlan.yearly,
        source: EntitlementSource.store,
        expiresAt: DateTime.utc(2027, 1, 2, 3, 4, 5),
      );

      final restored = Entitlement.fromJson(original.toJson())!;

      expect(restored.plan, PremiumPlan.yearly);
      expect(restored.source, EntitlementSource.store);
      expect(restored.expiresAt, original.expiresAt);
    });

    test('round-trips a lifetime purchase', () {
      const original = Entitlement.lifetime(EntitlementSource.store);
      final restored = Entitlement.fromJson(original.toJson())!;

      expect(restored.plan, PremiumPlan.lifetime);
      expect(restored.expiresAt, isNull);
    });

    test('keeps the QA source distinguishable from a purchase', () {
      const original = Entitlement.lifetime(EntitlementSource.qaOverride);
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

    test('a subscription stored without an expiry is rejected', () {
      // Missing expiry means "never expires", which only lifetime may claim —
      // otherwise a truncated record becomes an unbounded grant.
      expect(
        Entitlement.fromJson({
          'product_id': PremiumPlan.monthly.productId,
          'source': 'store',
          'expires_at': null,
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
      expect(PremiumPlan.monthly.productId, 'thaishield_premium_monthly');
      expect(PremiumPlan.yearly.productId, 'thaishield_premium_yearly');
      expect(PremiumPlan.lifetime.productId, 'thaishield_premium_lifetime');
    });

    test('only lifetime is a one-time product', () {
      expect(PremiumPlan.monthly.isSubscription, isTrue);
      expect(PremiumPlan.yearly.isSubscription, isTrue);
      expect(PremiumPlan.lifetime.isSubscription, isFalse);
      expect(PremiumPlan.lifetime.duration, isNull);
    });

    test('fromProductId resolves what the stores will send back', () {
      for (final plan in PremiumPlan.values) {
        expect(PremiumPlan.fromProductId(plan.productId), plan);
      }
      expect(PremiumPlan.fromProductId('unknown'), isNull);
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
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await EntitlementStore.instance.clear();
    });

    test('ships locked — no override flag in a plain build', () {
      // `flutter test` passes no --dart-define, which is the shape of a
      // release build. If this ever passes, the app ships unlocked.
      expect(PremiumProvider.qaOverrideFlag, isFalse);
    });

    test('starts free with nothing stored', () async {
      final provider = PremiumProvider();
      await provider.load();

      expect(provider.isLoaded, isTrue);
      expect(provider.isPremium, isFalse);
      expect(provider.entitlement, isNull);
      expect(provider.isQaUnlocked, isFalse);
    });

    test('a QA unlock grants access and survives a reload', () async {
      final provider = PremiumProvider();
      await provider.load();
      await provider.qaUnlock(PremiumPlan.yearly);

      expect(provider.isPremium, isTrue);
      expect(provider.isQaUnlocked, isTrue);
      expect(provider.entitlement!.source, EntitlementSource.qaOverride);

      final reloaded = PremiumProvider();
      await reloaded.load();
      expect(reloaded.isPremium, isTrue);
      expect(reloaded.isQaUnlocked, isTrue);
    });

    test('a QA lock clears it again', () async {
      final provider = PremiumProvider();
      await provider.load();
      await provider.qaUnlock(PremiumPlan.lifetime);
      expect(provider.isPremium, isTrue);

      await provider.qaLock();
      expect(provider.isPremium, isFalse);
      expect(await EntitlementStore.instance.read(), isNull);
    });

    test('notifies listeners so gates rebuild', () async {
      final provider = PremiumProvider();
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

      final provider = PremiumProvider();
      await provider.load();

      expect(provider.entitlement, isNotNull);
      expect(provider.isPremium, isFalse);
    });

    test('purchase and restore report that billing is not live yet', () async {
      // Phase 2C task 2.8 replaces these two bodies; the paywall already
      // handles every value of the enum.
      final provider = PremiumProvider();
      expect(
        await provider.purchase(PremiumPlan.yearly),
        StoreOutcome.notAvailableYet,
      );
      expect(await provider.restore(), StoreOutcome.notAvailableYet);
    });

    test('the free radar allowance is a small positive number', () {
      expect(PremiumProvider.freeRadarResultLimit, greaterThan(0));
      expect(PremiumProvider.freeRadarResultLimit, lessThan(10));
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
        expect(appStrings['premium_status_expires']![language], contains('{date}'));
        expect(appStrings['premium_locked_results']![language], contains('{count}'));
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

      // Both stores require auto-renew and cancellation to be disclosed
      // alongside a subscription price.
      final legal = appStrings['premium_legal_note']!['en']!.toLowerCase();
      expect(legal, contains('automatically'));
      expect(legal, contains('cancel'));
    });

    test('the price note points at the store, not at the figure on screen', () {
      // `PremiumPlan.priceThb` is a THB figure compiled into the app. What the
      // user is actually charged is the store's localised, tax-inclusive
      // price, so the screen must not present its own number as the deal.
      final note = appStrings['premium_price_note']!['en']!.toLowerCase();
      expect(note, contains('google play'));
      expect(note, contains('app store'));
    });

    test('the prices match the client design (feature-design.jpg)', () {
      // Received 2026-08-19. Pinned because these are the figures the client
      // published, and a silent drift here becomes a pricing dispute.
      expect(PremiumPlan.monthly.priceThb, 99);
      expect(PremiumPlan.yearly.priceThb, 799);
      expect(PremiumPlan.lifetime.priceThb, 1999);
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
      final entry =
          RadarZoneEntry(zone: zone, distanceKm: 0, isInside: true);
      expect(entry.group, RadarGroup.zoneDanger);
    });
  });
}
