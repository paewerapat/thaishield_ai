import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/activity_log.dart';
import 'features/home/screens/home_screen.dart';
import 'features/premium/providers/premium_provider.dart';
import 'features/onboarding/screens/language_selection_screen.dart';
import 'firebase_options.dart';
import 'features/premium/services/billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final localeProvider = LocaleProvider();
  await localeProvider.loadSavedLocale();

  // Loaded before the first frame, like the locale, so no screen ever has to
  // render an "entitlement unknown" state. See PremiumProvider.isLoaded.
  //
  // 🚨 `billing:` is what connects the app to Google Play and StoreKit.
  // PremiumProvider defaults it to null so that widget tests can build screens
  // without opening a platform channel — which means dropping this argument
  // does not break a single test, does not fail analyze, and does not crash
  // anything. It just makes every purchase and every restore answer
  // "billing is not available in this build", quietly, forever.
  //
  // `test/main_wiring_test.dart` reads this file and fails if the argument
  // disappears. Do not delete that test to make a refactor pass.
  //
  // `activityLog:` is what fills the CMS's App Users and Transactions pages.
  // It carries the same silent-failure shape as `billing:` — drop the argument
  // and nothing breaks, no test fails and no user notices; the client's admin
  // simply reports that nobody has ever opened the app. `main_wiring_test.dart`
  // guards this line too.
  final premiumProvider = PremiumProvider(
    billing: InAppPurchaseBilling(),
    activityLog: FirestoreActivityLog(),
  );
  await premiumProvider.load();

  // Not awaited: this is a Firestore write on the launch path, and a slow or
  // unreachable network must not hold the first frame. It is fire-and-forget
  // all the way down — see the class comment on ActivityLog.
  //
  // The locale is sent only once the user has actually picked one. Before that
  // `LocaleProvider` holds its `en` default, and reporting that would file
  // every first launch as an English speaker — including the Thai and Chinese
  // users the language screen is there to catch. Null leaves the field alone
  // and the next launch fills it in.
  premiumProvider.recordUsage(
    locale: await localeProvider.hasSelectedLocale()
        ? localeProvider.locale.languageCode
        : null,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: premiumProvider),
      ],
      child: const ThaiShieldApp(),
    ),
  );
}

class ThaiShieldApp extends StatelessWidget {
  const ThaiShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return MaterialApp(
      title: 'ThaiShield',
      debugShowCheckedModeBanner: false,
      locale: locale,
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FC3F7),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.promptTextTheme(),
        useMaterial3: true,
      ),
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _loading = true;
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final hasLocale =
        await context.read<LocaleProvider>().hasSelectedLocale();
    if (mounted) {
      setState(() {
        _showOnboarding = !hasLocale;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
        ),
      );
    }

    if (_showOnboarding) {
      return LanguageSelectionScreen(
        onLanguageSelected: () {
          setState(() => _showOnboarding = false);
        },
      );
    }

    return const HomeScreen();
  }
}
