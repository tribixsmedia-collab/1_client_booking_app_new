import 'package:flutter/material.dart';
import '../utils/breakpoints.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/assistant_fab.dart';
import '../widgets/web_top_nav.dart';
import 'home_tab.dart';
import 'my_bookings_screen.dart';
import 'profile_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  /// Which tab a pushed route has asked the shell to show.
  ///
  /// The desktop top bar is drawn on detail pages too, and "Home" there means
  /// "leave this page and show the home tab" — but a pushed route cannot
  /// reach this screen's state. It parks the index here and pops back to the
  /// root, which is listening.
  static final ValueNotifier<int> requestedTab = ValueNotifier<int>(0);

  /// Pops back to the shell and switches it to [index].
  static void openTab(BuildContext context, int index) {
    requestedTab.value = index;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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

  @override
  void initState() {
    super.initState();
    MainNavigationScreen.requestedTab.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    MainNavigationScreen.requestedTab.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final index = MainNavigationScreen.requestedTab.value;
    if (mounted && index != _currentIndex) _onTabTapped(index);
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    MainNavigationScreen.requestedTab.value = index;
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
      // On every tab, not just Help & Support: most of what the assistant
      // answers is asked while browsing. Scaffold keeps it clear of the
      // bottom tabs on phones on its own.
      floatingActionButton: const AssistantFab(),
      bottomNavigationBar: desktop
          ? null
          : AppBottomNav(currentIndex: _currentIndex, onTap: _onTabTapped),
    );
  }
}
