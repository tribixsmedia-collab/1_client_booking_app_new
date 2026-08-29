import 'package:flutter/material.dart';
import '../utils/breakpoints.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/web_top_nav.dart';
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
    HomeTab(onOpenBookings: () => _onTabTapped(1)),
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
    // On a monitor the navigation moves to a top bar, the way a website
    // does it. Phones keep the bottom tabs untouched.
    final desktop = isDesktopLayout(context);
    return Scaffold(
      body: Column(
        children: [
          if (desktop)
            WebTopNav(currentIndex: _currentIndex, onTabSelected: _onTabTapped),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: desktop
          ? null
          : AppBottomNav(currentIndex: _currentIndex, onTap: _onTabTapped),
    );
  }
}
