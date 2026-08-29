import 'package:flutter/material.dart';

import '../config.dart';
import '../screens/cart_screen.dart';
import '../screens/search_screen.dart';
import '../services/api_service.dart';
import '../services/branding_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import '../utils/breakpoints.dart';
import '../utils/location_update.dart';
import '../utils/profile_gate.dart';
import 'app_logo.dart';
import 'notification_bell.dart';

/// The desktop web header: brand, section links, location, search and the
/// account controls, all on one bar.
///
/// This replaces the bottom tab bar above [kDesktopBreakpoint]. A bottom nav
/// is a phone convention; on a monitor the controls belong at the top, where
/// every other website keeps them.
class WebTopNav extends StatefulWidget {
  const WebTopNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  @override
  State<WebTopNav> createState() => _WebTopNavState();
}

class _WebTopNavState extends State<WebTopNav> {
  final _cart = CartService();
  String? _address;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _load();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final signedIn = !kGuestBrowsing || await ApiService.isLoggedIn();
    if (!mounted) return;
    setState(() => _signedIn = signedIn);
    if (!signedIn) return;
    try {
      final profile = await ApiService.getMyProfile();
      if (mounted) setState(() => _address = profile['address'] as String?);
    } catch (_) {}
  }

  Future<void> _changeLocation() async {
    if (!await requireSignIn(context)) return;
    if (!mounted) return;
    final updated = await pickAndSaveLocation(context);
    if (updated != null && mounted) setState(() => _address = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SizedBox(
          height: 74,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kDesktopContentWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _brand(),
                    const SizedBox(width: 36),
                    _link('Home', 0),
                    _link('Bookings', 1),
                    const Spacer(),
                    Flexible(child: _locationPill()),
                    const SizedBox(width: 12),
                    Flexible(child: _searchBox()),
                    const SizedBox(width: 18),
                    const NotificationBell(),
                    const SizedBox(width: 10),
                    _cartButton(),
                    const SizedBox(width: 12),
                    _account(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return InkWell(
      onTap: () => widget.onTabSelected(0),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: BrandingBuilder(
          builder: (context) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 36),
              const SizedBox(width: 10),
              Text(
                BrandingService.appName ?? 'Home Service',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(String label, int index) {
    final active = widget.currentIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: () => widget.onTabSelected(index),
        style: TextButton.styleFrom(
          foregroundColor: active ? AppColors.primary : AppColors.textDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _locationPill() {
    final hasAddress = _address != null && _address!.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: InkWell(
        onTap: _changeLocation,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasAddress ? _address! : 'Set your location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBox() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 19, color: AppColors.textGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search for a service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartButton() {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.textDark,
              size: 24,
            ),
            if (_cart.totalItems > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${_cart.totalItems}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _account() {
    if (!_signedIn) {
      return OutlinedButton(
        onPressed: () async {
          if (await requireSignIn(context)) _load();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Sign in',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      );
    }
    return IconButton(
      onPressed: () => widget.onTabSelected(2),
      tooltip: 'Account',
      icon: Icon(
        Icons.person_outline_rounded,
        color: widget.currentIndex == 2
            ? AppColors.primary
            : AppColors.textDark,
      ),
    );
  }
}
