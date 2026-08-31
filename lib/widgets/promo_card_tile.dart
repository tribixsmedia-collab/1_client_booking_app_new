import 'package:flutter/material.dart';

import '../utils/image_decode.dart';

/// Large full-bleed promo card on the home page: image behind, an optional
/// badge chip and headline over the top, and a solid button at the bottom.
/// Everything on it is admin-managed (Dashboard -> Promo Cards).
class PromoCardTile extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  const PromoCardTile({super.key, required this.card, required this.onTap});

  /// Parses the '#RRGGBB' the dashboard colour picker sends, falling back to
  /// the default badge colour if an admin ever saves something odd.
  static Color _parseHex(String? hex, Color fallback) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = card['image'] as String?;
    final badgeText = (card['badge_text'] as String?) ?? '';
    final title = (card['title'] as String?) ?? '';
    final subtitle = (card['subtitle'] as String?) ?? '';
    final buttonText = (card['button_text'] as String?) ?? 'Book now';
    final badgeColor = _parseHex(
      card['badge_color'] as String?,
      const Color(0xFF9C1458),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Full width of whatever it is given - the page on a phone, the
            // content column on the web. Only the height is capped: the card
            // is square on a phone, and letting that ratio hold across a
            // 1240px column would make it a 1240px-tall block.
            final width = constraints.maxWidth;
            return SizedBox(
              width: width,
              height: width > 380 ? 380 : width,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        // The card spans the screen minus its 20pt side padding.
                        cacheWidth: decodeWidthFor(
                          context,
                          MediaQuery.sizeOf(context).width - 40,
                        ),
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),

                    // Darkens just the top and bottom so the text and button stay
                    // readable whatever image the admin uploads.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badgeText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (title.isNotEmpty)
                            Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),

                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const Spacer(),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
