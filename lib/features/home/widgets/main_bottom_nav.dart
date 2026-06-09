import 'package:flutter/material.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    _TabConfig(Icons.home_outlined, Icons.home_rounded, 'Home', Color(0xFF4FC3F7)),
    _TabConfig(Icons.document_scanner_outlined, Icons.document_scanner_rounded, 'Scan', Color(0xFF4FC3F7)),
    _TabConfig(Icons.map_outlined, Icons.map_rounded, 'Map', Color(0xFF2E7D32)),
    _TabConfig(Icons.sos_outlined, Icons.sos_rounded, 'SOS', Color(0xFFEF5350)),
    _TabConfig(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', Color(0xFF4FC3F7)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/menu-bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(
              _tabs.length,
              (i) => _buildTab(i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = _tabs[index];
    final isActive = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? tab.activeIcon : tab.icon,
              color: isActive ? tab.color : const Color(0xFFBDBDBD),
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                color: isActive ? tab.color : const Color(0xFFBDBDBD),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabConfig {
  const _TabConfig(this.icon, this.activeIcon, this.label, this.color);
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
}
