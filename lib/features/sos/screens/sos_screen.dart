import 'package:flutter/material.dart';
import '../../../core/localization/app_text.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SosHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _PlaceholderIcon(),
                    const SizedBox(height: 16),
                    const Text(
                      'AI Voice SOS',
                      style: TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appText(context, 'sos_coming_soon'),
                      style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.sos_rounded, color: Color(0xFFEF5350), size: 22),
          const SizedBox(width: 8),
          const Text(
            'AI Voice SOS',
            style: TextStyle(
              color: Color(0xFF0D1B2A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(Icons.help_outline_rounded, color: Colors.grey[400], size: 22),
        ],
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.record_voice_over_outlined,
        color: Color(0xFFEF5350),
        size: 52,
      ),
    );
  }
}
