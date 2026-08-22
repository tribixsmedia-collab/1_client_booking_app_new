import 'package:flutter/material.dart';

import '../theme.dart';
import 'service_card.dart';

/// A horizontal strip of services personal to this customer — "Recently
/// viewed" and "Book again". Renders nothing at all when the customer has no
/// history yet, so a new account never sees an empty heading.
class PersonalizedRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<dynamic> services;

  /// Draws the "Booked Nx" ribbon on each card, for the book-again row.
  final bool showTimesBooked;

  const PersonalizedRow({
    super.key,
    required this.title,
    required this.services,
    this.subtitle = '',
    this.showTimesBooked = false,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final service = Map<String, dynamic>.from(services[index]);
                final card = ServiceCard.fromJson(service);
                final times = service['times_booked'] as int? ?? 0;

                if (!showTimesBooked || times < 2) return card;

                return Stack(
                  children: [
                    card,
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Booked ${times}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
