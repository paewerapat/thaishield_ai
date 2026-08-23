// On-device journeys — the tests that need a real Android runtime.
//
// Everything that can be proved without a device already is: 146 unit tests
// and 13 widget tests. What is left here is what only a device can answer —
// does the app boot with real Firebase, does the shell navigate, does a fresh
// install actually get its trial, does changing language change the app.
//
// Run:  flutter test integration_test -d emulator-5554
//
// 🚨 These clear SharedPreferences on the device. Run them on an emulator or a
// dedicated test handset, never on a phone whose app state someone cares about.
//
// What still cannot be covered here, and is therefore still a manual pass in
// QA_PHASE_2B.md: camera capture, microphone/STT, a real GPS fix, the Google
// Maps deep link (no Maps app on a bare AVD), and anything involving a real
// purchase.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/core/providers/locale_provider.dart';
import 'package:thaishield_ai/features/home/screens/home_screen.dart';
import 'package:thaishield_ai/features/onboarding/screens/language_selection_screen.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/firebase_options.dart';

/// Mirrors `main.dart`'s widget tree, but built per test so each one starts
/// from a known entitlement and locale.
///
/// `main()` itself is not called: it initialises Firebase, and calling it once
/// per test would throw `duplicate-app` on the second. Firebase is initialised
/// once in [setUpAll] instead, which is the same thing the app does — just
/// hoisted so the suite can own it.
Widget _app({
  required LocaleProvider locale,
  required PremiumProvider premium,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: locale),
      ChangeNotifierProvider.value(value: premium),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: context.watch<LocaleProvider>().locale,
        supportedLocales: const [
          Locale('th'),
          Locale('en'),
          Locale('zh'),
          Locale('ko'),
          Locale('ru'),
          Locale('ja'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
}

/// The map and the news list both hit the network on first build. `pumpAndSettle`
/// waits for an idle frame that may never come while something is loading, so
/// these journeys pump for a fixed span instead and assert on what is on screen
/// at the end of it.
Future<void> _settle(WidgetTester tester,
    [Duration span = const Duration(seconds: 6)]) async {
  final end = DateTime.now().add(span);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<({LocaleProvider locale, PremiumProvider premium})> _freshState({
  String language = 'th',
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  final locale = LocaleProvider();
  await locale.setLocale(Locale(language));

  final premium = PremiumProvider();
  await premium.load();

  return (locale: locale, premium: premium);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // Already initialised by a previous run in the same process.
      if (e.code != 'duplicate-app') rethrow;
    }
  });

  testWidgets('B1 — a fresh install is asked to choose a language',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final locale = LocaleProvider();
    await locale.loadSavedLocale();
    final premium = PremiumProvider();
    await premium.load();

    expect(
      await locale.hasSelectedLocale(),
      isFalse,
      reason: 'a cleared install must not think a language was chosen',
    );

    await tester.pumpWidget(
      _app(
        locale: locale,
        premium: premium,
        home: LanguageSelectionScreen(onLanguageSelected: () {}),
      ),
    );
    await _settle(tester, const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('B2 — the shell shows all five tabs and every one opens',
      (tester) async {
    final state = await _freshState();

    await tester.pumpWidget(
      _app(locale: state.locale, premium: state.premium, home: const HomeScreen()),
    );
    await _settle(tester);

    // The bottom bar is the app's whole navigation. If a tab label goes
    // missing, users lose a feature with no error anywhere.
    for (final key in [
      'nav_home',
      'nav_scan',
      'nav_map',
      'nav_sos',
      'nav_profile',
    ]) {
      expect(
        find.text(appStrings[key]!['th']!),
        findsWidgets,
        reason: 'missing bottom nav item: $key',
      );
    }

    for (final key in ['nav_scan', 'nav_map', 'nav_sos', 'nav_profile', 'nav_home']) {
      await tester.tap(find.text(appStrings[key]!['th']!).last);
      await _settle(tester, const Duration(seconds: 4));
      expect(
        tester.takeException(),
        isNull,
        reason: 'opening $key threw',
      );
    }
  });

  testWidgets('B3 — a fresh install is granted the three-day trial',
      (tester) async {
    final state = await _freshState();

    expect(state.premium.isPremium, isFalse, reason: 'starts locked');

    await tester.pumpWidget(
      _app(locale: state.locale, premium: state.premium, home: const HomeScreen()),
    );
    await _settle(tester);

    expect(state.premium.isPremium, isTrue, reason: 'trial did not start');
    expect(state.premium.isOnTrial, isTrue);
    expect(state.premium.daysRemaining, 3);
    expect(state.premium.entitlement!.source, EntitlementSource.trial);
  });

  testWidgets('B4 — the trial is granted once per install, not once per launch',
      (tester) async {
    final state = await _freshState();

    await tester.pumpWidget(
      _app(locale: state.locale, premium: state.premium, home: const HomeScreen()),
    );
    await _settle(tester);
    expect(state.premium.isOnTrial, isTrue);

    // Second "launch": same device state, a brand new provider — which is what
    // reopening the app does.
    final second = PremiumProvider();
    await second.load();
    expect(await second.startTrialIfEligible(), isFalse);
  });

  testWidgets('B5 — changing language changes the app, not just the setting',
      (tester) async {
    final state = await _freshState(language: 'th');

    await tester.pumpWidget(
      _app(locale: state.locale, premium: state.premium, home: const HomeScreen()),
    );
    await _settle(tester);
    expect(find.text(appStrings['nav_home']!['th']!), findsWidgets);

    await state.locale.setLocale(const Locale('ja'));
    await _settle(tester, const Duration(seconds: 3));

    expect(find.text(appStrings['nav_home']!['ja']!), findsWidgets);
    expect(find.text(appStrings['nav_home']!['th']!), findsNothing);
  });

  testWidgets('B6 — the trial survives a relaunch with its clock running',
      (tester) async {
    final state = await _freshState();

    await tester.pumpWidget(
      _app(locale: state.locale, premium: state.premium, home: const HomeScreen()),
    );
    await _settle(tester);

    final expiry = state.premium.entitlement!.expiresAt;

    final reopened = PremiumProvider();
    await reopened.load();

    expect(reopened.isPremium, isTrue);
    expect(reopened.isOnTrial, isTrue);
    expect(
      reopened.entitlement!.expiresAt,
      expiry,
      reason: 'a relaunch must not restart the 3 days',
    );
  });
}
