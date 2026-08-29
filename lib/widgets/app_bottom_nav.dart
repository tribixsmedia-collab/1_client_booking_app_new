import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Bottom navigation for the customer app.
///
/// The selected tab grows into a tinted pill carrying its label while the
/// others stay as bare icons, so the current position reads at a glance
/// without three labels competing for attention.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Bookings',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Align(
            alignment: Alignment.center,
            // heightFactor pins the bar to the height of the pills. A bare
            // Center expands into the loose constraints bottomNavigationBar
            // hands down, and eats the entire body.
            heightFactor: 1,
            child: ConstrainedBox(
              // Phones are narrower than this so they are unaffected; it only
              // stops the three pills drifting to the far corners of a
              // desktop window.
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _NavPill(
                      item: _items[i],
                      isActive: i == currentIndex,
                      onTap: () {
                        if (i == currentIndex) return;
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavPill extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavPill({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 260);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 20,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textGrey,
            ),

            // Only the selected tab shows its label, sliding out as it grows.
            AnimatedSize(
              duration: _duration,
              curve: _curve,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
