import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key, required this.onLanguageSelected});

  final VoidCallback onLanguageSelected;

  static const _languages = [
    _LangOption(code: 'th', flag: '🇹🇭', label: 'ไทย / Thai', highlighted: true),
    _LangOption(code: 'en', flag: '🇬🇧', label: 'English'),
    _LangOption(code: 'zh', flag: '🇨🇳', label: '中文 / Chinese'),
    _LangOption(code: 'ko', flag: '🇰🇷', label: '한국어 / Korean'),
    _LangOption(code: 'ru', flag: '🇷🇺', label: 'Русский / Russian'),
    _LangOption(code: 'ja', flag: '🇯🇵', label: '日本語 / Japanese'),
  ];

  void _select(BuildContext context, String code) {
    context.read<LocaleProvider>().setLocale(Locale(code));
    onLanguageSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1810),
      body: SafeArea(
        child: Column(
          children: [
            _buildLogoSection(),
            Expanded(child: _buildLanguageList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 140,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'ThaiShield ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                TextSpan(
                  text: 'AI',
                  style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'เที่ยวไทย ปลอดภัย ฉลาดเลือก',
            style: TextStyle(color: Color(0xFF8FAF94), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2D5A35)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF4CAF50), size: 14),
                SizedBox(width: 6),
                Text(
                  "don't get lost, don't get scammed",
                  style: TextStyle(color: Color(0xFF8FAF94), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _languages.length,
      itemBuilder: (context, index) {
        final lang = _languages[index];
        return _LangRow(
          option: lang,
          onTap: () => _select(context, lang.code),
        );
      },
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({required this.option, required this.onTap});

  final _LangOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (option.highlighted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A4020),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D6E38), width: 1.5),
            ),
            child: Row(
              children: [
                Text(option.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF4CAF50), size: 22),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A2E1C), width: 1)),
        ),
        child: Row(
          children: [
            Text(option.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(color: Color(0xFFD0E8D4), fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A6B4F), size: 20),
          ],
        ),
      ),
    );
  }
}

class _LangOption {
  const _LangOption({
    required this.code,
    required this.flag,
    required this.label,
    this.highlighted = false,
  });

  final String code;
  final String flag;
  final String label;
  final bool highlighted;
}
