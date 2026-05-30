import 'package:flutter/material.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', color: Color(0xFF4FC3F7)),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map', color: Color(0xFF66BB6A)),
    _NavItem(icon: Icons.document_scanner_outlined, activeIcon: Icons.document_scanner, label: 'Scan', color: Color(0xFF4FC3F7)),
    _NavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield, label: 'SOS', color: Color(0xFFEF5350)),
  ];

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
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = currentIndex == index;
              final isSos = index == 3;

              if (isSos) {
                return Expanded(child: _SosButton(item: item, isActive: isActive, onTap: () => onTap(index)));
              }

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive ? item.color : const Color(0xFF455A64),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isActive ? item.color : const Color(0xFF455A64),
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.item, required this.isActive, required this.onTap});

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEF5350) : const Color(0xFF1A3A5C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive ? Colors.white : const Color(0xFF455A64),
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              color: isActive ? const Color(0xFFEF5350) : const Color(0xFF455A64),
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
}
