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

  static const _screens = [
    HomeTab(),
    ScannerScreen(),
    MapScreen(),
    SosScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
