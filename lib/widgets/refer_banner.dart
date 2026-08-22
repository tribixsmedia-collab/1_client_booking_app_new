import 'package:flutter/material.dart';

import '../screens/refer_earn_screen.dart';
import '../theme.dart';

/// Wide "Refer and get free services" strip that closes out the home page.
class ReferBanner extends StatelessWidget {
  final Map<String, dynamic> info;

  const ReferBanner({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReferEarnScreen(info: info)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
        color: AppColors.primary.withValues(alpha: 0.07),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['home_banner_title'] ?? '',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info['home_banner_subtitle'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('🎁', style: TextStyle(fontSize: 56)),
          ],
        ),
      ),
    );
  }
}

/// Boxed "Refer & earn ₹50" card with its own button, for the profile page.
class ReferCard extends StatelessWidget {
  final Map<String, dynamic> info;

  const ReferCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReferEarnScreen(info: info)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info['profile_card_title'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        info['profile_card_subtitle'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Text('🎁', style: TextStyle(fontSize: 46)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: open,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                info['profile_card_button'] ?? 'Refer now',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
