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
    final isActive = currentIndex == 1;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF4FC3F7) : const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isActive ? Icons.document_scanner : Icons.document_scanner_outlined,
                color: isActive ? const Color(0xFF0D1B2A) : const Color(0xFF455A64),
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan',
              style: TextStyle(
                color: isActive ? const Color(0xFF4FC3F7) : const Color(0xFF455A64),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosTab() {
    final isActive = currentIndex == 3;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFEF5350) : const Color(0xFF2A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.sos,
                color: isActive ? Colors.white : const Color(0xFF455A64),
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SOS',
              style: TextStyle(
                color: isActive ? const Color(0xFFEF5350) : const Color(0xFF455A64),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
