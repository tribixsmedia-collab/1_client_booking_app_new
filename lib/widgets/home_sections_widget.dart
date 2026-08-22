import 'package:flutter/material.dart';
import '../theme.dart';
import '../screens/section_see_all_screen.dart';
import 'promo_card_tile.dart';
import 'service_card.dart';

class HomeSectionsWidget extends StatelessWidget {
  final List<dynamic> sections;

  /// Admin-managed promo cards. Each one carries a `placement` telling us
  /// whether it goes before the sections, after a particular one, or after
  /// the lot — see the Promo Cards page in the dashboard.
  final List<dynamic> promoCards;
  final void Function(Map<String, dynamic> card)? onPromoTap;

  const HomeSectionsWidget({
    super.key,
    required this.sections,
    this.promoCards = const [],
    this.onPromoTap,
  });

  /// Promo cards for one slot, already ordered by the API.
  List<Widget> _cardsFor(String placement, {int? sectionId}) {
    return promoCards
        .where((c) {
          if (c['placement'] != placement) return false;
          if (sectionId == null) return true;
          return c['after_section'] == sectionId;
        })
        .map<Widget>((c) {
          final card = Map<String, dynamic>.from(c);
          return PromoCardTile(
            card: card,
            onTap: () => onPromoTap?.call(card),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty && promoCards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._cardsFor('BEFORE_SECTIONS'),
        ...sections.expand<Widget>(
          (section) => [
            _buildSection(context, section),
            ..._cardsFor('AFTER_SECTION', sectionId: section['id']),
          ],
        ),
        ..._cardsFor('AFTER_SECTIONS'),
      ],
    );
  }

  Widget _buildSection(BuildContext context, dynamic section) {
    final items = (section['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

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
                          if ((section['subtitle'] as String?)?.isNotEmpty ??
                              false)
                            Text(
                              section['subtitle'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((section['total_items'] as int? ?? 0) >
                        (section['home_display_limit'] as int? ?? 3))
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SectionSeeAllScreen(
                                sectionId: section['id'],
                                title: section['title'] ?? '',
                                subtitle: section['subtitle'] ?? '',
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
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => ServiceCard.fromJson(
                    Map<String, dynamic>.from(items[index]),
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

