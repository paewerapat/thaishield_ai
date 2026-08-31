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
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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

/// Catches what the paywall's legal links actually try to open.
///
/// The store requirement is not "a label exists", it is "a reviewer can tap
/// this and land on the terms". Only tapping proves that, so these tests go
/// through url_launcher's platform interface rather than reading strings.
class _RecordingLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

/// Both store-required links must point at the site this project actually
/// publishes, over https.
///
/// Asserting only that a URL ends in `/terms` lets it be moved to any host in
/// the world with the suite still green — including one nobody controls, which
/// on a page stating billing terms is worse than a dead link.
void _expectOurPublicSite(String url) {
  final uri = Uri.parse(url);
  expect(uri.scheme, 'https', reason: '$url is not served over https');
  expect(
    uri.host,
    'thaishield-admin--thaishield-ai-790eb.asia-southeast1.hosted.app',
    reason: '$url is not on the site this project publishes',
  );
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

PartnerLocation _partner(
  String id, {
  double rating = 4.5,
  String type = 'restaurant',
  String imageUrl = '',
}) =>
    PartnerLocation(
      id: id,
      name: 'Partner $id',
      lat: 13.72,
      lng: 100.52,
      type: type,
      rating: rating,
      isVerified: true,
      priceTier: 'fair',
      imageUrl: imageUrl,
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

      // $3.50 keeps its decimal, $10 drops the trailing zero — the weekly
      // plan gained a fractional price when it stopped being a 14-day pass.
      expect(find.text('\$3.50'), findsOneWidget);
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
          of: cardFor(PremiumPlan.weekly),
          matching: find.byIcon(Icons.radio_button_unchecked_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.text(appStrings[PremiumPlan.weekly.titleKey]!['th']!),
      );
      await tester.pumpAndSettle();

      // …and the selection actually moved.
      expect(
        find.descendant(
          of: cardFor(PremiumPlan.weekly),
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

      // Two now, not one: the nearby-partner row and the "what's around you"
      // card both describe the same nearest place, which is what the design
      // poster draws. The assertion is that the distance is printed in metres
      // inside the radius, not how many sections mention it.
      expect(find.text('200 ม.'), findsWidgets);
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

      // 'Partner 0' is now printed twice — the nearby row and the
      // "what's around you" card for its category. Both hand back the same
      // entry, so tapping the first is the row and is what this covers.
      await tester.tap(find.text('Partner 0').first);
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

    testWidgets('the you-are-here block survives all six languages',
        (tester) async {
      // Added with the block itself. Its zone pill and "updated at" line sit
      // in a Wrap because the Russian and Japanese area names are long — the
      // map legend overflowed by 5.7px the last time long text went into a
      // fixed row, and analyze and 166 tests all passed while it did.
      for (final language in ['th', 'en', 'zh', 'ko', 'ru', 'ja']) {
        await tester.pumpWidget(
          _host(
            AroundYouPanel(
              result: _around(zones: ['danger'], partners: 2),
              isPremium: true,
              onShowEntry: (_) {},
              onUnlock: () {},
              address: 'สยามสแควร์, เขตปทุมวัน, กรุงเทพมหานคร',
              updatedAt: DateTime(2026, 8, 29, 9, 30),
              onViewAll: () {},
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        // 🚨 Deliberately does not open the sheet.
        //
        // `_openSheet` drags it up, and a `ListView` disposes children that
        // leave the viewport rather than merely hiding them — so once the
        // category cards made the content taller, the same drag destroyed the
        // header and no finder could see it. This block is at the very top and
        // is visible in the collapsed sheet, which is exactly where it has to
        // read correctly in six languages.
        expect(
          tester.takeException(),
          isNull,
          reason: 'you-are-here block threw in $language',
        );
        expect(
          find.text(appStrings['around_you_are_at']![language]!),
          findsOneWidget,
          reason: 'no "you are here" heading in $language',
        );
      }
    });

    testWidgets('an unmapped spot says so instead of implying it is safe',
        (tester) async {
      // §10: silence about an area is missing information, never an all-clear.
      // With no zone underfoot the pill must read "no information", and must
      // not borrow the safe-area wording.
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: _around(zones: ['caution'], partners: 1),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
            address: 'Pathum Wan',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(
        find.text(appStrings['around_no_zone']!['th']!, skipOffstage: false),
        findsOneWidget,
        reason: 'an unmapped spot did not say its information is missing',
      );

      // Note what is NOT asserted here. An earlier version of this test also
      // checked that the safe-area wording appears nowhere — and failed,
      // because the count tiles carry that label permanently as a heading for
      // "safe areas nearby". The tiles are counting; only the pill is making a
      // statement about where the user is standing. The distinction is the
      // whole point, so the assertion is scoped to the pill's own string.
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

  group('the "what is around you" cards', () {
    /// The strip sits below the advisory and partner lists, so with more than
    /// a couple of entries it starts life outside the viewport — and a
    /// `ListView` does not build children it has not reached. Scroll to it
    /// rather than asserting it is missing.
    Future<void> scrollToStrip(WidgetTester tester) async {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    // The design poster's photo strip. Built from the partners already loaded
    // for the pins, so it costs no extra Firestore read and cannot disagree
    // with the map behind it.

    RadarResult withTypes(List<String> types) => RadarResult(
          center: const LatLng(13.72, 100.52),
          radiusKm: 1,
          entries: [
            for (var i = 0; i < types.length; i++)
              RadarPartnerEntry(
                partner: _partner('$i', type: types[i]),
                distanceKm: 0.2 + i * 0.05,
              ),
          ],
        );

    testWidgets('one card per category that has something nearby',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: withTypes(['restaurant', 'hotel', 'restaurant']),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);
      await scrollToStrip(tester);

      expect(find.text(appStrings['around_whats_here']!['th']!), findsOneWidget);
      // Two restaurants and one hotel — two cards, not three.
      expect(find.text(appStrings['cat_restaurant']!['th']!), findsWidgets);
      expect(find.text(appStrings['cat_hotel']!['th']!), findsWidgets);
    });

    testWidgets('a category with nothing nearby gets no card', (tester) async {
      // Five empty cards read as a broken screen, not as an empty area.
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: withTypes(['restaurant']),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(find.text(appStrings['cat_hotel']!['th']!), findsNothing);
      expect(find.text(appStrings['cat_transport']!['th']!), findsNothing);
    });

    testWidgets('the strip is absent when nothing is nearby at all',
        (tester) async {
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

      expect(find.text(appStrings['around_whats_here']!['th']!), findsNothing);
    });

    testWidgets('a partner with no photo still gets a card', (tester) async {
      // `partner_locations.image_url` is allowed to be "" and many rows are.
      // The card falls back to the category icon rather than a broken image.
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: withTypes(['restaurant']),
            isPremium: true,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(appStrings['around_whats_here']!['th']!), findsOneWidget);
    });

    testWidgets('the cards are free, like the counts beside them',
        (tester) async {
      // A strip of five padlocks on the first screen a tourist opens is a wall,
      // not an upsell. What stays paid is the lists past the free limit and the
      // filter panel.
      await tester.pumpWidget(
        _host(
          AroundYouPanel(
            result: withTypes(['restaurant', 'hotel']),
            isPremium: false,
            onShowEntry: (_) {},
            onUnlock: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);
      await scrollToStrip(tester);

      expect(find.text(appStrings['around_whats_here']!['th']!), findsOneWidget);
    });
  });

  group('the store-required legal links', () {
    // 🚨 The reason this group exists: the first attempt at guarding these
    // links only asserted that two dictionary entries were non-empty. Deleting
    // `const _LegalLinks()` from paywall_screen.dart left every test in the
    // repo green, while producing exactly the build Apple rejects. A test that
    // cannot fail when the feature is removed is not covering the feature.

    late _RecordingLauncher launcher;
    late UrlLauncherPlatform original;

    setUp(() {
      original = UrlLauncherPlatform.instance;
      launcher = _RecordingLauncher();
      UrlLauncherPlatform.instance = launcher;
    });

    tearDown(() => UrlLauncherPlatform.instance = original);

    /// The paywall body is a `ListView`, so anything below the fold is never
    /// built and `find.text` cannot see it. A phone-sized surface leaves the
    /// links off-screen, which is a property of the test window and not of the
    /// screen — so give the test a window tall enough to build the whole list.
    Future<void> pumpTallPaywall(
      WidgetTester tester, {
      String language = 'th',
    }) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const PaywallScreen(), language: language));
      await tester.pumpAndSettle();
    }

    testWidgets('both links are on the screen in every language',
        (tester) async {
      for (final language in ['th', 'en', 'zh', 'ko', 'ru', 'ja']) {
        await pumpTallPaywall(tester, language: language);

        for (final key in ['premium_terms_link', 'premium_privacy_link']) {
          expect(
            find.text(appStrings[key]![language]!),
            findsOneWidget,
            reason: '$key is not drawn in $language — the store rejects this',
          );
        }
      }
    });

    testWidgets('tapping Terms opens the public terms page', (tester) async {
      await pumpTallPaywall(tester);

      await tester.tap(find.text(appStrings['premium_terms_link']!['th']!));
      await tester.pumpAndSettle();

      expect(launcher.launched, hasLength(1));
      expect(Uri.parse(launcher.launched.single).path, '/terms');
      _expectOurPublicSite(launcher.launched.single);
    });

    testWidgets('tapping Privacy opens the public privacy page',
        (tester) async {
      await pumpTallPaywall(tester);

      await tester.tap(find.text(appStrings['premium_privacy_link']!['th']!));
      await tester.pumpAndSettle();

      expect(launcher.launched, hasLength(1));
      expect(Uri.parse(launcher.launched.single).path, '/privacy');
      _expectOurPublicSite(launcher.launched.single);
    });

    testWidgets('neither link sits behind the CMS login', (tester) async {
      // Auth is enforced in the web admin's `app/admin/layout.tsx`, so a page
      // under /admin redirects a signed-out visitor. A store reviewer has no
      // account, so a link that lands there fails review just as surely as a
      // dead one.
      await pumpTallPaywall(tester);

      for (final key in ['premium_terms_link', 'premium_privacy_link']) {
        await tester.tap(find.text(appStrings[key]!['th']!));
        await tester.pumpAndSettle();
      }

      expect(launcher.launched, hasLength(2));
      for (final url in launcher.launched) {
        expect(
          Uri.parse(url).path.startsWith('/admin'),
          isFalse,
          reason: '$url is behind the admin login',
        );
      }
    });
  });
}
