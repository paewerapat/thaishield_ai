import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key, required this.onLanguageSelected});

  final VoidCallback onLanguageSelected;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedCode;

  static const _languages = [
    _LangOption(code: 'en', label: 'English', native: 'English', flag: '🇬🇧'),
    _LangOption(code: 'zh', label: 'Chinese', native: '中文', flag: '🇨🇳'),
    _LangOption(code: 'ru', label: 'Russian', native: 'Русский', flag: '🇷🇺'),
    _LangOption(code: 'ko', label: 'Korean', native: '한국어', flag: '🇰🇷'),
    _LangOption(code: 'ja', label: 'Japanese', native: '日本語', flag: '🇯🇵'),
  ];

  void _onContinue() {
    if (_selectedCode == null) return;
    context.read<LocaleProvider>().setLocale(Locale(_selectedCode!));
    widget.onLanguageSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 40),
              Expanded(child: _buildLanguageList()),
              const SizedBox(height: 24),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Color(0xFF4FC3F7),
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ThaiShield',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select Your Language',
          style: TextStyle(
            color: Color(0xFF90CAF9),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose your preferred language to continue',
          style: TextStyle(
            color: Color(0xFF607D8B),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLanguageList() {
    return ListView.separated(
      itemCount: _languages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lang = _languages[index];
        final isSelected = _selectedCode == lang.code;
        return _LanguageCard(
          option: lang,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedCode = lang.code),
        );
      },
    );
  }

  Widget _buildContinueButton() {
    final isEnabled = _selectedCode != null;
    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: isEnabled ? _onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4FC3F7),
          foregroundColor: const Color(0xFF0D1B2A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _LangOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A3A5C) : const Color(0xFF152230),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4FC3F7)
                : const Color(0xFF1E3048),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(option.flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.native,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    option.label,
                    style: const TextStyle(
                      color: Color(0xFF607D8B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4FC3F7),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _LangOption {
  const _LangOption({
    required this.code,
    required this.label,
    required this.native,
    required this.flag,
  });

  final String code;
  final String label;
  final String native;
  final String flag;
}
