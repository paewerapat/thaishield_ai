import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: Color(0xFF4FC3F7), size: 64),
            SizedBox(height: 16),
            Text(
              'Smart Map',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Phase 2 — Coming Soon',
              style: TextStyle(color: Color(0xFF607D8B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
