import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/providers/locale_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/onboarding/screens/language_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeProvider = LocaleProvider();
  await localeProvider.loadSavedLocale();
  runApp(
    ChangeNotifierProvider.value(
      value: localeProvider,
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
