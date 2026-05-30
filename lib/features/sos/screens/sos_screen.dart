import 'package:flutter/material.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over_outlined, color: Color(0xFFEF5350), size: 64),
            SizedBox(height: 16),
            Text(
              'AI Voice SOS',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Phase 4 — Coming Soon',
              style: TextStyle(color: Color(0xFF607D8B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
