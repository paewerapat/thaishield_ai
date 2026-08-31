import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
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

  group('the Home card', () {
    testWidgets('invites a free user to the plans', (tester) async {
      final provider = PremiumProvider(repository: _NullRepository());
      await provider.load();

      await tester.pumpWidget(_host(const PremiumHomeCard(), premium: provider));
      await tester.pumpAndSettle();

      expect(find.text('PREMIUM'), findsOneWidget);
      expect(
        find.text(appStrings['premium_strip_title']!['th']!),
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

      // Says how long is left, rather than pretending nothing is happening.
      expect(find.textContaining('เหลือ'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
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

    testWidgets('never advertises a feature that was cancelled',
        (tester) async {
      // 🚨 The poster's card promises "real-time in-depth data". That is AI
      // Local Insights, which was cancelled, and the 24-hour updates, which
      // describe news that is already free for everyone. The layout is the
      // poster's; the words must not be.
      await tester.pumpWidget(_host(const PremiumHomeCard()));
      await tester.pumpAndSettle();

      for (final phrase in [
        'AI Local Insights',
        'Offline Map',
        'Smart Alerts',
        'เรียลไทม์',
        'ออฟไลน์',
      ]) {
        expect(
          find.textContaining(phrase),
          findsNothing,
          reason: 'the card advertises "$phrase", which the app does not do',
        );
      }
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
