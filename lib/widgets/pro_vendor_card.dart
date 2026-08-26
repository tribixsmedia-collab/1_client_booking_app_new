import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/image_decode.dart';

/// The badge that marks a vendor as admin-approved. Used on the cards and
/// again at the top of the profile screen so the two read as the same thing.
class ProBadge extends StatelessWidget {
  final double fontSize;

  const ProBadge({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.22,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: fontSize * 1.1, color: Colors.white),
          SizedBox(width: fontSize * 0.3),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round photo with a graceful fall-back to the vendor's initial, so a pro
/// the admin has not uploaded a picture for still looks deliberate.
class ProVendorAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;

  const ProVendorAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              cacheWidth: decodeWidthFor(context, size),
              errorBuilder: (_, __, ___) => _initialLabel(initial),
            )
          : _initialLabel(initial),
    );
  }

  Widget _initialLabel(String initial) => Center(
    child: Text(
      initial,
      style: TextStyle(
        fontSize: size * 0.38,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    ),
  );
}

/// A pro vendor as shown in the home rows and the "See all" grid.
///
/// The JSON is whatever `/api/vendors/pro/` returns, so the same widget backs
/// the curated sections, the service page row and the see-all screen.
class ProVendorCard extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final VoidCallback onTap;
  final double width;

  const ProVendorCard({
    super.key,
    required this.vendor,
    required this.onTap,
    this.width = 170,
  });

  @override
  Widget build(BuildContext context) {
    final name = (vendor['name'] as String?) ?? '';
    final title = (vendor['pro_title'] as String?) ?? '';
    final rating = ((vendor['average_rating'] as num?) ?? 0).toDouble();
    final reviews = (vendor['total_reviews'] as int?) ?? 0;
    final years = (vendor['experience_years'] as int?) ?? 0;
    final categories = (vendor['categories'] as List<dynamic>?) ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProVendorAvatar(
              photoUrl: vendor['photo'] as String?,
              name: name,
              size: 64,
            ),
            const SizedBox(height: 8),
            const ProBadge(),
            const SizedBox(height: 6),

            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            if (title.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ] else if (categories.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                categories.join(', '),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],

            const SizedBox(height: 8),
            // A pro with no reviews yet gets their experience instead of an
            // empty "0.0" that reads as a bad score.
            reviews > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 15, color: Color(0xFFFFB300)),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '($reviews)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  )
                : Text(
                    years > 0 ? '$years yr${years == 1 ? '' : 's'} exp' : 'New pro',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// The wider, horizontal variant used at the bottom of a service page, where
/// there is room for the tagline and a "Book" action.
class ProVendorListTile extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final VoidCallback onTap;
  final VoidCallback? onBook;
  final bool isSelected;

  const ProVendorListTile({
    super.key,
    required this.vendor,
    required this.onTap,
    this.onBook,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = (vendor['name'] as String?) ?? '';
    final title = (vendor['pro_title'] as String?) ?? '';
    final tagline = (vendor['pro_tagline'] as String?) ?? '';
    final rating = ((vendor['average_rating'] as num?) ?? 0).toDouble();
    final reviews = (vendor['total_reviews'] as int?) ?? 0;
    final years = (vendor['experience_years'] as int?) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProVendorAvatar(
              photoUrl: vendor['photo'] as String?,
              name: name,
              size: 54,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const ProBadge(fontSize: 9),
                    ],
                  ),

                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),

                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                        height: 1.3,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (reviews > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 15, color: Color(0xFFFFB300)),
                        const SizedBox(width: 3),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviews)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (years > 0)
                        Text(
                          '$years yr${years == 1 ? '' : 's'} exp',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (onBook != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onBook,
                style: TextButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor:
                      isSelected ? Colors.white : AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isSelected ? 'Selected' : 'Book',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
