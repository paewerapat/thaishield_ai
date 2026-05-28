import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: const Text(
          'ThaiShield',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF4FC3F7)),
            onPressed: () => context.read<LocaleProvider>().setLocale(
                  const Locale('en'),
                ),
            tooltip: 'Language: ${locale.languageCode.toUpperCase()}',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF4FC3F7),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ThaiShield',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Language: ${locale.languageCode.toUpperCase()}',
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Phase 2 — Map & Alerts coming soon',
              style: TextStyle(color: Color(0xFF607D8B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
