// Widget-level QA for the screens the 2026-08-22 package change rewrote.
//
// The unit tests in premium_test.dart prove the *model* is right — two passes,
// no lifetime, correct expiry. They cannot prove the screen draws what the
// model says, and that is exactly where the last round of changes could have
// gone wrong: a leftover third card, a THB symbol, a renewal promise nobody
// removed from the layout.
//
// These run without a device or a network, so they belong in every commit,
// unlike the on-device suite in integration_test/.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/core/models/alert_zone.dart';
import 'package:thaishield_ai/core/models/partner_location.dart';
import 'package:thaishield_ai/features/map/widgets/around_you_panel.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/models/premium_plan.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/screens/paywall_screen.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_store.dart';
import 'package:thaishield_ai/features/radar/models/radar_result.dart';

/// Firestore is never reached in these tests — the panel and the paywall are
/// both handed their data — but `PremiumProvider` holds a repository, so it
/// needs one that does nothing rather than one that tries to open a network
/// connection from a test binary.
class _NullRepository implements EntitlementRepository {
  @override
  Future<void> save(Entitlement entitlement) async {}

  @override
  Future<Entitlement?> fetch(String purchaseId) async => null;

  @override
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async => null;
}

Widget _host(Widget child, {String language = 'th', PremiumProvider? premium}) {
  return ChangeNotifierProvider<PremiumProvider>.value(
    value: premium ?? PremiumProvider(repository: _NullRepository()),
    child: MaterialApp(
      locale: Locale(language),
      // Mirrors main.dart. Without the delegates every non-English locale logs
      // an "unsupported locale" warning, which the six-language checks below
      // correctly treat as a failure.
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

PartnerLocation _partner(String id, {double rating = 4.5}) => PartnerLocation(
      id: id,
      name: 'Partner $id',
      lat: 13.72,
      lng: 100.52,
      type: 'restaurant',
      rating: rating,
      isVerified: true,
      priceTier: 'fair',
      imageUrl: '',
    );

AlertZone _zone(String id, String riskLevel) => AlertZone(
      id: id,
      name: 'Zone $id',
      centerLat: 13.72,
      centerLng: 100.52,
      radiusKm: 0.5,
      riskLevel: riskLevel,
      descriptionEn: 'English description',
      descriptionTh: 'คำอธิบายภาษาไทย',
    );

RadarResult _around({List<String> zones = const [], int partners = 0}) {
  return RadarResult(
    center: const LatLng(13.72, 100.52),
    radiusKm: 1,
    entries: [
      for (var i = 0; i < zones.length; i++)
        RadarZoneEntry(
          zone: _zone('$i', zones[i]),
          distanceKm: 0.1 + i * 0.05,
          isInside: false,
        ),
      for (var i = 0; i < partners; i++)
        RadarPartnerEntry(partner: _partner('$i'), distanceKm: 0.2 + i * 0.05),
    ],
  );
}


/// The sheet opens at 16% of the screen, so everything below the drag handle is
/// off-stage and — because the body is a lazy ListView — not even built. Tests
/// that assert on content have to open it first, exactly as a user does.
Future<void> _openSheet(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.dragFrom(
    Offset(size.width / 2, size.height - 30),
    Offset(0, -size.height * 0.5),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EntitlementStore.instance.clear();
  });

  group('paywall — what the screen actually draws', () {
    testWidgets('shows exactly the two passes that exist', (tester) async {
      await tester.pumpWidget(_host(const PaywallScreen()));
      await tester.pumpAndSettle();

      for (final plan in PremiumPlan.values) {
        expect(
          find.text(appStrings[plan.titleKey]!['th']!),
          findsOneWidget,
          reason: '${plan.name} card is missing',
        );
      }

      // The cancelled plans must not survive anywhere on the screen — a
      // leftover card is the failure this whole change could produce.
      for (final gone in ['premium_plan_yearly', 'premium_plan_lifetime']) {
        expect(appStrings[gone], isNull, reason: '$gone still has copy');
      }
      expect(find.textContaining('ตลอดชีพ'), findsNothing);
      expect(find.textContaining('รายปี'), findsNothing);
    });

    testWidgets('prices are USD, and no baht figure survives', (tester) async {
      await tester.pumpWidget(_host(const PaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('\$7'), findsOneWidget);
      expect(find.text('\$10'), findsOneWidget);
      expect(find.textContaining('฿'), findsNothing);
    });

    testWidgets('the trial is explained under the cards, never sold as part of a pass',
        (tester) async {
      // The 3 free days go to a new install on first launch. Buying a pass
      // grants nothing free, so a "3 days free" badge on a price was an offer
      // the purchase could never honour — the QA gate flagged it 2026-08-23 and
      // it was removed. What remains is the accurate note beneath the cards.
      await tester.pumpWidget(_host(const PaywallScreen()));
      await tester.pumpAndSettle();

      final note = appStrings['premium_trial_note']!['th']!;
      await tester.scrollUntilVisible(find.text(note), 200);
      await tester.pumpAndSettle();

      expect(find.text(note), findsOneWidget);
      expect(
        appStrings['premium_trial_badge'],
        isNull,
        reason: 'the badge copy should have been removed with the badge',
      );
    });

    testWidgets('discloses the platform split rather than promising restore',
        (tester) async {
      // Accepted limitation 2026-08-23. If someone ever "tidies" this note back
      // into one sentence, this test is what says no.
      await tester.pumpWidget(_host(const PaywallScreen()));
      await tester.pumpAndSettle();

      final note = appStrings['premium_platform_note']!['th']!;
      // The notes sit below the fold under the buttons, so scroll to them the
      // way a user reading the small print would.
      await tester.scrollUntilVisible(find.text(note), 200);
      await tester.pumpAndSettle();

      expect(find.text(note), findsOneWidget);
      expect(note.contains('Android'), isTrue);
      expect(note.contains('iOS'), isTrue);
    });

    testWidgets('tapping a plan card moves the selection to it', (tester) async {
      // Written first as "exactly one radio is checked, before and after",
      // which cannot fail: one is always checked because `recommended` is the
      // initial selection, so a dead tap handler passed. The QA gate flagged it
      // on 2026-08-23. It now asserts *which* card holds the selection, which is
      // the thing that decides what the user is charged.
      Finder cardFor(PremiumPlan plan) => find.ancestor(
            of: find.text(appStrings[plan.titleKey]!['th']!),
            matching: find.byType(InkWell),
          );

      await tester.pumpWidget(_host(const PaywallScreen()));
      await tester.pumpAndSettle();

      // Opens on the recommended plan — the 30-day pass.
      expect(
        find.descendant(
          of: cardFor(PremiumPlan.monthly),
          matching: find.byIcon(Icons.radio_button_checked_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFor(PremiumPlan.twoWeeks),
          matching: find.byIcon(Icons.radio_button_unchecked_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.text(appStrings[PremiumPlan.twoWeeks.titleKey]!['th']!),
      );
      await tester.pumpAndSettle();

      // …and the selection actually moved.
      expect(
        find.descendant(
          of: cardFor(PremiumPlan.twoWeeks),
          matching: find.byIcon(Icons.radio_button_checked_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFor(PremiumPlan.monthly),
          matching: find.byIcon(Icons.radio_button_unchecked_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders in all six languages without overflowing',
        (tester) async {
      // Thai and Russian are the long ones; Japanese and Korean change line
      // breaking. An overflow here is a red-and-yellow banner in front of a
      // paying customer.
      for (final language in ['th', 'en', 'zh', 'ko', 'ru', 'ja']) {
        await tester.pumpWidget(_host(const PaywallScreen(), language: language));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'paywall threw in $language',
        );
      }
    });
  });

  group('around-you panel — what the map draws', () {
    testWidgets('draws nothing at all before there is a position',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: null,
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('รอบตัวคุณ'), findsNothing);
    });

    testWidgets('counts every area but lists only the advisories',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: _around(zones: ['safe', 'safe', 'caution'], partners: 2),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // Two safe areas counted in the tiles…
      expect(find.text('2'), findsWidgets);
      // …and the alerts heading present because one caution area exists.
      expect(
        find.text(appStrings['around_alerts_title']!['th']!),
        findsOneWidget,
      );
      // A safe zone must never appear as an advisory row.
      expect(find.text('Zone 0'), findsNothing);
      expect(find.text('Zone 2'), findsOneWidget);
    });

    testWidgets('prints distances in metres inside the radius', (tester) async {
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: _around(partners: 1),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(find.text('200 ม.'), findsOneWidget);
    });

    testWidgets('a tapped row hands the entry back to the map', (tester) async {
      RadarEntry? tapped;
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: _around(partners: 1),
            isPremium: true,
            onShowEntry: (entry) => tapped = entry,
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await tester.tap(find.text('Partner 0'));
      await tester.pumpAndSettle();

      expect(tapped, isA<RadarPartnerEntry>());
    });

    testWidgets('free tier trims the lists but never the counts',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: _around(partners: 7),
            isPremium: false,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      // The tile still says 7 even though only 3 rows are drawn.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Partner 0'), findsOneWidget);
      expect(find.text('Partner 3'), findsNothing);
    });

    testWidgets('says so when the radius holds nothing', (tester) async {
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: _around(),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(find.text(appStrings['around_empty']!['th']!), findsOneWidget);
    });

    testWidgets('renders in all six languages without overflowing',
        (tester) async {
      for (final language in ['th', 'en', 'zh', 'ko', 'ru', 'ja']) {
        await tester.pumpWidget(
          _host(
            AroundYouPanel(
              result: _around(zones: ['caution'], partners: 3),
              isPremium: false,
              onShowEntry: (_) {},
              onUnlock: () {},
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        await _openSheet(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'panel threw in $language',
        );
      }
    });
  });
}
