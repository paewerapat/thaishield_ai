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
    _TabConfig(Icons.map_outlined, Icons.map_rounded, 'Map', Color(0xFF66BB6A)),
    _TabConfig(Icons.sos_outlined, Icons.sos_rounded, 'SOS', Color(0xFFEF5350)),
    _TabConfig(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', Color(0xFF4FC3F7)),
  ];

  static const _textShadow = [
    Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/menu-bg.png'),
          fit: BoxFit.fill,
          alignment: Alignment.center,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) => _buildTab(i)),
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
        splashColor: tab.color.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? tab.color.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                color: isActive ? tab.color : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                color: isActive ? tab.color : Colors.white,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                shadows: _textShadow,
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
