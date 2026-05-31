import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../onboarding/screens/language_selection_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildLanguageTile(context, locale.languageCode),
          const SizedBox(height: 12),
          _buildInfoTile(Icons.info_outline, 'About ThaiShield AI', 'Version 1.0.0'),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, String langCode) {
    final flags = {'th': '🇹🇭', 'en': '🇬🇧', 'zh': '🇨🇳', 'ko': '🇰🇷', 'ru': '🇷🇺', 'ja': '🇯🇵'};
    return ListTile(
      tileColor: const Color(0xFF152230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Text(flags[langCode] ?? '🌐', style: const TextStyle(fontSize: 24)),
      title: const Text('Language', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(langCode.toUpperCase(), style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF607D8B)),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF0A1810),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => LanguageSelectionScreen(
            onLanguageSelected: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      tileColor: const Color(0xFF152230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: const Color(0xFF4FC3F7)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF607D8B), fontSize: 12)),
    );
  }
}
