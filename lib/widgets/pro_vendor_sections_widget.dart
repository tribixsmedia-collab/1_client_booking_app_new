import 'package:flutter/material.dart';
import '../screens/pro_vendor_detail_screen.dart';
import '../screens/pro_vendor_see_all_screen.dart';
import '../theme.dart';
import 'pro_vendor_card.dart';

/// The admin-curated Pro Vendor rows on the home screen.
///
/// Mirrors [HomeSectionsWidget]: same header, same "See all" rule, but the
/// items are pro vendors rather than services.
class ProVendorSectionsWidget extends StatelessWidget {
  final List<dynamic> sections;

  const ProVendorSectionsWidget({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections
          .map<Widget>((section) => _buildSection(context, section))
          .toList(),
    );
  }

  Widget _buildSection(BuildContext context, dynamic section) {
    final items = (section['items'] as List<dynamic>?) ?? [];
    // A section whose members were all un-flagged since curation comes back
    // empty — drop it rather than leaving a headed row with nothing under it.
    if (items.isEmpty) return const SizedBox.shrink();

    final total = (section['total_items'] as int?) ?? 0;
    final limit = (section['home_display_limit'] as int?) ?? 5;
    final subtitle = (section['subtitle'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['title'] ?? '',
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
                if (total > limit)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProVendorSeeAllScreen(
                            sectionId: section['id'],
                            title: section['title'] ?? '',
                            subtitle: subtitle,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final vendor = Map<String, dynamic>.from(items[index]);
                return ProVendorCard(
                  vendor: vendor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProVendorDetailScreen(
                          vendorId: vendor['id'] as int,
                          preview: vendor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
