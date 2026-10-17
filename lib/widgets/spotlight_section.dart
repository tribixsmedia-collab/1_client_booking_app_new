import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/breakpoints.dart';
import '../utils/image_decode.dart';

class SpotlightSection extends StatelessWidget {
  final List<dynamic> spotlights;
  final void Function(Map<String, dynamic> banner) onTap;

  const SpotlightSection({
    super.key,
    required this.spotlights,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (spotlights.isEmpty) return const SizedBox.shrink();

    // Bigger on a monitor, where there is room for it and the titles were
    // being clipped mid-word. Left alone on phones: 280 is already most of
    // a 375px screen, and widening it there would just hide the next card.
    final desktop = isDesktopLayout(context);
    final cardWidth = desktop ? 360.0 : 280.0;
    final rowHeight = desktop ? 232.0 : 180.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'In the spotlight',
            style: displayHeading(size: desktop ? 21 : 18),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: spotlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final banner = spotlights[index];
              return _SpotlightCard(
                title: banner['title'] ?? '',
                subtitle: banner['subtitle'] ?? '',
                imageUrl: banner['background_image'],
                buttonText: banner['button_text'] ?? 'Book now',
                width: cardWidth,
                roomy: desktop,
                onTap: () => onTap(Map<String, dynamic>.from(banner)),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String buttonText;
  final double width;

  /// Desktop sizing: a wider card with room for a second subtitle line and
  /// slightly larger type.
  final bool roomy;
  final VoidCallback onTap;

  const _SpotlightCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.buttonText,
    required this.width,
    required this.roomy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade200,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidthFor(context, width),
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey.shade300),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: roomy ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: roomy ? 6 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: roomy ? 13 : 12,
                        height: 1.35,
                      ),
                      maxLines: roomy ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
  }
}
