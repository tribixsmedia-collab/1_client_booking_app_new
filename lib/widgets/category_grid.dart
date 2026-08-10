import 'package:flutter/material.dart';
import '../theme.dart';

class CategoryCard extends StatelessWidget {
  final String name;
  // final dynamic price;
  final String? iconUrl;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.name,
    // required this.price,
    required this.iconUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: iconUrl != null && iconUrl!.isNotEmpty
                  ? Image.network(
                      iconUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.build,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    )
                  : const Icon(Icons.build, color: AppColors.primary, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          // const SizedBox(height: 2),
          // Text(
          //   '₹$price',
          //   style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
          // ),
        ],
      ),
    );
  }
}

class MoreCard extends StatelessWidget {
  final int remainingCount;
  final VoidCallback onTap;

  const MoreCard({
    super.key,
    required this.remainingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'More',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '+$remainingCount more',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class SubcategoryItem extends StatelessWidget {
  final String name;
  final String? iconUrl;
  final VoidCallback onTap;

  const SubcategoryItem({
    super.key,
    required this.name,
    required this.iconUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 80) / 3,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: iconUrl != null && iconUrl!.isNotEmpty
                    ? Image.network(
                        iconUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.build,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.build,
                        color: AppColors.primary,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
