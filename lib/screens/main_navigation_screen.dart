import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import 'home_tab.dart';
import 'my_bookings_screen.dart';
import 'profile_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final _profileKey = GlobalKey<ProfileTabState>();

  late final List<Widget> _tabs = [
    const HomeTab(),
    const MyBookingsScreen(),
    ProfileTab(key: _profileKey, onOpenBookings: () => _onTabTapped(1)),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 2) {
      _profileKey.currentState?.loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
