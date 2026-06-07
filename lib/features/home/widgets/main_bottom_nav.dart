import 'package:flutter/material.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        border: Border(top: BorderSide(color: Color(0xFF1E3048), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _buildTab(0, Icons.home_outlined, Icons.home, 'Home', const Color(0xFF4FC3F7)),
              _buildScanTab(),
              _buildTab(2, Icons.map_outlined, Icons.map, 'Map', const Color(0xFF66BB6A)),
              _buildSosTab(),
              _buildTab(4, Icons.person_outline, Icons.person, 'Profile', const Color(0xFF90CAF9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, IconData activeIcon, String label, Color color) {
    final isActive = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? color : const Color(0xFF455A64),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : const Color(0xFF455A64),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanTab() {
    return _buildTab(
      1,
      Icons.document_scanner_outlined,
      Icons.document_scanner,
      'Scan',
      const Color(0xFF4FC3F7),
    );
  }

  Widget _buildSosTab() {
    return _buildTab(3, Icons.sos_outlined, Icons.sos, 'SOS', const Color(0xFFEF5350));
  }
}
