import 'package:flutter/material.dart';
import '../../map/screens/map_screen.dart';
import '../../scanner/screens/scanner_screen.dart';
import '../../sos/screens/sos_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/home_tab.dart';
import '../widgets/main_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _mapPartnerTypeFilter;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  String _scanCategoryToPartnerType(String category) {
    switch (category) {
      case 'transport':
        return 'transport';
      case 'attraction':
        return 'hotel';
      default:
        return 'restaurant';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(onNavigateToTab: _goToTab),
      ScannerScreen(
        onViewNearbyPartners: (category) {
          setState(() => _mapPartnerTypeFilter = _scanCategoryToPartnerType(category));
          _goToTab(2);
        },
      ),
      MapScreen(partnerTypeFilter: _mapPartnerTypeFilter),
      const SosScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentIndex,
        onTap: _goToTab,
      ),
    );
  }
}
