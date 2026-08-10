import 'package:flutter/material.dart';
import '../theme.dart';
import 'booking_screen.dart';

/// Shows subcategories under a selected category.
/// If no subcategories exist, goes straight to booking.
class CategoryDetailScreen extends StatelessWidget {
  final int categoryId;
  final String categoryName;
  final dynamic basePrice;
  final List<dynamic> subcategories;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.basePrice,
    required this.subcategories,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose a service',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Select the specific service you need under $categoryName.',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // "General" option — book without a subcategory
          _ServiceTile(
            name: '$categoryName (General)',
            price: basePrice,
            iconUrl: null,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingScreen(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    basePrice: basePrice,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Subcategories from DB
          ...subcategories.map((sub) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceTile(
                name: sub['name'],
                price: sub['base_price'],
                iconUrl: sub['icon'],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                        categoryId: categoryId,
                        categoryName: '${categoryName} - ${sub['name']}',
                        basePrice: sub['base_price'],
                        subcategoryId: sub['id'],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String name;
  final dynamic price;
  final String? iconUrl;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.name,
    required this.price,
    required this.iconUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 52,
            height: 52,
            color: AppColors.primary.withValues(alpha: 0.08),
            child: iconUrl != null && iconUrl!.isNotEmpty
                ? Image.network(
                    iconUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.build, color: AppColors.primary),
                  )
                : const Icon(Icons.build, color: AppColors.primary),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'From ₹$price',
          style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textGrey,
        ),
        onTap: onTap,
      ),
    );
  }
}
