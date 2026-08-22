import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../map/screens/map_screen.dart';
import '../../premium/providers/premium_provider.dart';
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
  MapFocusRequest? _mapFocus;

  @override
  void initState() {
    super.initState();
    // The 3-day trial is granted here rather than in `main()` because
    // `PremiumProvider.load` has to have finished first — and this is the
    // first screen that exists once it has. It is cheap and local: no network,
    // no permission prompt, and it returns immediately for anyone who has
    // already had a trial or is holding a pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PremiumProvider>().startTrialIfEligible();
    });
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  /// Switches to the Map tab and recenters it — used by the Safety Radar and
  /// the Alert Zone proximity card.
  void _showOnMap(MapFocusRequest request) {
    setState(() {
      _mapFocus = request;
      _currentIndex = 2;
    });
  }

  /// Maps a scanned `price_standards.category` onto a
  /// `partner_locations.type`. Since the 3→11 category expansion (Phase 2A
  /// task 2.3) "attraction" has a real counterpart and no longer has to
  /// borrow "hotel".
  String _scanCategoryToPartnerType(String category) {
    switch (category) {
      case 'transport':
        return 'transport';
      case 'attraction':
        return 'attraction';
      default:
        return 'restaurant';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(
        onNavigateToTab: _goToTab,
        onShowOnMap: _showOnMap,
        isActive: _currentIndex == 0,
      ),
      ScannerScreen(
        onViewNearbyPartners: (category) {
          setState(() => _mapPartnerTypeFilter = _scanCategoryToPartnerType(category));
          _goToTab(2);
        },
      ),
      MapScreen(
        partnerTypeFilter: _mapPartnerTypeFilter,
        focusRequest: _mapFocus,
        isActive: _currentIndex == 2,
      ),
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
