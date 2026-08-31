import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/models/premium_feature.dart';
import 'package:thaishield_ai/features/premium/models/premium_plan.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';
import 'package:thaishield_ai/features/premium/widgets/premium_promo.dart';

/// The Home upsell the client asked for on 2026-08-31 ("the home screen is
/// very empty ... it should invite people to buy Premium").
class _NullRepository implements EntitlementRepository {
  @override
  Future<void> save(Entitlement entitlement) async {}
  @override
  Future<Entitlement?> fetch(String purchaseId) async => null;
  @override
  Future<Entitlement?> restoreBest(Iterable<String> ids) async => null;
}

const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

Widget _host(Widget child, {String language = 'th', PremiumProvider? premium}) {
  return ChangeNotifierProvider<PremiumProvider>.value(
    value: premium ?? PremiumProvider(repository: _NullRepository()),
    child: MaterialApp(
      locale: Locale(language),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: _languages.map(Locale.new).toList(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the feature strip only sells what exists', () {
    testWidgets('it names every gated feature and nothing else',
        (tester) async {
      await tester.pumpWidget(_host(const PremiumFeaturesStrip()));
      await tester.pumpAndSettle();

      for (final feature in PremiumFeature.values) {
        expect(
          find.text(appStrings[feature.headlineKey]!['th']!),
          findsOneWidget,
          reason: '${feature.name} is gated but not advertised',
        );
      }
    });

    testWidgets('it does not advertise the cancelled features', (tester) async {
      // 🚨 The design poster's premium band lists six things. Three were
      // cancelled outright — AI Local Insights, Offline Map and Smart Alerts —
      // and a fourth, "real-time updates, 24 hours", describes news that
      // already refreshes every ten minutes for everyone, free. Copying that
      // band would be taking a subscription for four things the app does not
      // do, from a tourist, in six languages.
      await tester.pumpWidget(_host(const PremiumFeaturesStrip()));
      await tester.pumpAndSettle();

      const cancelled = [
        'AI Local Insights',
        'Offline Map',
        'Smart Alerts',
        'ออฟไลน์',
        'แจ้งเตือนอัตโนมัติ',
      ];
      for (final phrase in cancelled) {
        expect(
          find.textContaining(phrase),
          findsNothing,
          reason: 'the strip advertises "$phrase", which does not exist',
        );
      }
    });

    testWidgets('renders in all six languages without overflowing',
        (tester) async {
      for (final language in _languages) {
        await tester.pumpWidget(
          _host(const PremiumFeaturesStrip(), language: language),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: language);
      }
    });
  });

  group('the Home card', () {
    testWidgets('invites a free user to the plans', (tester) async {
      final provider = PremiumProvider(repository: _NullRepository());
      await provider.load();

      await tester.pumpWidget(_host(const PremiumHomeCard(), premium: provider));
      await tester.pumpAndSettle();

      expect(
        find.text(appStrings['premium_promo_headline']!['th']!),
        findsOneWidget,
      );
      expect(find.text(appStrings['premium_cta']!['th']!), findsOneWidget);
    });

    testWidgets('still appears while the trial is running', (tester) async {
      // 🚨 The regression this pins. A fresh install is on trial from its first
      // launch, so anything hidden when access is active is hidden from
      // everyone who has not paid — which is what made the entire paywall
      // unreachable for three days.
      final provider = PremiumProvider(repository: _NullRepository());
      await provider.load();
      await provider.startTrialIfEligible();
      expect(provider.isOnTrial, isTrue);

      await tester.pumpWidget(_host(const PremiumHomeCard(), premium: provider));
      await tester.pumpAndSettle();

      expect(
        find.text(appStrings['premium_promo_trial_headline']!['th']!),
        findsOneWidget,
      );
    });

    testWidgets('says something true to a subscriber, and still links out',
        (tester) async {
      final provider = PremiumProvider(repository: _NullRepository());
      await provider.load();
      await provider.grantPurchase(
        plan: PremiumPlan.monthly,
        purchaseId: 'GPA.paid',
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 20)),
      );

      await tester.pumpWidget(_host(const PremiumHomeCard(), premium: provider));
      await tester.pumpAndSettle();

      expect(
        find.text(appStrings['premium_status_active_title']!['th']!),
        findsOneWidget,
      );
      // Not an upsell for them — a way to read what they pay for and to find
      // the cancel instructions, which live on the plans screen.
      expect(
        find.text(appStrings['premium_upgrade_action']!['th']!),
        findsOneWidget,
      );
    });

    testWidgets('renders in all six languages without overflowing',
        (tester) async {
      for (final language in _languages) {
        await tester.pumpWidget(
          _host(const PremiumHomeCard(), language: language),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: language);
      }
    });
  });
}
