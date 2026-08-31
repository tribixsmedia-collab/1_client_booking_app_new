import 'package:flutter/material.dart';

import '../screens/refer_earn_screen.dart';
import '../screens/support_screen.dart';
import '../utils/breakpoints.dart';
import '../utils/profile_gate.dart';
import 'app_logo.dart';
import '../services/branding_service.dart';

/// Page footer for the desktop web layout.
///
/// Every entry here goes to a screen that exists — there are no placeholder
/// "About us" or "Careers" links, because a footer full of dead ends is worse
/// than a short one.
class WebFooter extends StatelessWidget {
  const WebFooter({super.key, required this.onOpenBookings});

  /// Bookings is a tab rather than a route, so the host screen switches to it.
  final VoidCallback onOpenBookings;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFF16162A),
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDesktopContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _brandBlock()),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 3,
                      child: _column('For customers', [
                        _FooterLink('Help & support', () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SupportScreen(),
                            ),
                          );
                        }),
                        _FooterLink('My bookings', onOpenBookings),
                        _FooterLink('Refer & earn', () async {
                          if (!await requireSignIn(context)) return;
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReferEarnScreen(),
                            ),
                          );
                        }),
                      ]),
                    ),
                    Expanded(
                      flex: 3,
                      child: _column('Legal', const [
                        _FooterLink('Terms of Service', null),
                        _FooterLink('Privacy Policy', null),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Divider(color: Colors.white.withValues(alpha: 0.12)),
                const SizedBox(height: 18),
                Text(
                  '© ${DateTime.now().year} '
                  '${BrandingService.appName ?? 'Home Service'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandBlock() {
    return BrandingBuilder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 34),
              const SizedBox(width: 10),
              Text(
                BrandingService.appName ?? 'Home Service',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            BrandingService.tagline?.isNotEmpty == true
                ? BrandingService.tagline!
                : 'Trusted professionals for every job around the house.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _column(String title, List<_FooterLink> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 14),
        for (final link in links) link,
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.onTap);

  final String label;

  /// Null renders plain text rather than something that looks clickable but
  /// is not — these documents do not exist as screens yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.5,
        color: Colors.white.withValues(alpha: onTap == null ? 0.45 : 0.75),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null ? text : InkWell(onTap: onTap, child: text),
    );
  }
}
