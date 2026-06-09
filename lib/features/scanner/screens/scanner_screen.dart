import 'package:flutter/material.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ScannerHeader(),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PlaceholderIcon(),
                    SizedBox(height: 16),
                    Text(
                      'AI Price Scanner',
                      style: TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Phase 3 — Coming Soon',
                      style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
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

class _ScannerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded, color: Color(0xFF4FC3F7), size: 22),
          const SizedBox(width: 8),
          const Text(
            'AI Price Scanner',
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
        color: const Color(0xFFE3F7FD),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.document_scanner_outlined,
        color: Color(0xFF4FC3F7),
        size: 52,
      ),
    );
  }
}
