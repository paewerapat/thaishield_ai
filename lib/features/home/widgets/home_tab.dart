import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildHeader(locale.languageCode.toUpperCase()),
            const SizedBox(height: 32),
            _buildFeatureCards(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String lang) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_outlined, color: Color(0xFF4FC3F7), size: 26),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ThaiShield',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Travel Safe · Stay Smart',
              style: TextStyle(color: Color(0xFF607D8B), fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            lang,
            style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards(BuildContext context) {
    final cards = [
      _FeatureCard(
        icon: Icons.document_scanner_outlined,
        title: 'AI Price Scanner',
        subtitle: 'สแกนเมนู ตรวจสอบราคา',
        color: const Color(0xFF4FC3F7),
        phase: 'Phase 3',
      ),
      _FeatureCard(
        icon: Icons.map_outlined,
        title: 'Smart Map',
        subtitle: 'แผนที่พาร์ทเนอร์ & โซนเตือนภัย',
        color: const Color(0xFF66BB6A),
        phase: 'Phase 2',
      ),
      _FeatureCard(
        icon: Icons.record_voice_over_outlined,
        title: 'AI Voice SOS',
        subtitle: 'พูดภาษาอังกฤษ สื่อสารทันที',
        color: const Color(0xFFEF5350),
        phase: 'Phase 4',
      ),
    ];

    return Column(
      children: cards.map((card) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _FeatureCardWidget(card: card),
      )).toList(),
    );
  }
}

class _FeatureCard {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.phase,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String phase;
}

class _FeatureCardWidget extends StatelessWidget {
  const _FeatureCardWidget({required this.card});
  final _FeatureCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF152230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3048)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(card.icon, color: card.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(card.subtitle,
                    style: const TextStyle(color: Color(0xFF607D8B), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(card.phase,
                style: TextStyle(color: card.color, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
