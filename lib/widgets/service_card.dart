import 'package:flutter/material.dart';

import '../screens/service_detail_screen.dart';
import '../screens/service_form_screen.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import '../utils/image_decode.dart';
import '../utils/profile_gate.dart';
class ServiceCard extends StatefulWidget {
  final int serviceId;
  final String name;
  final String description;
  final double price;
  final int? durationMinutes;
  final String? imageUrl;
  final int categoryId;
  final int? subcategoryId;
  final String categoryName;
  final double averageRating;
  final int totalReviews;
  final double? finalPrice;
  final double? discountAmount;

  const ServiceCard({
    super.key,
    required this.serviceId,
    required this.name,
    required this.description,
    required this.price,
    this.durationMinutes,
    this.imageUrl,
    required this.categoryId,
    this.subcategoryId,
    required this.categoryName,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.finalPrice,
    this.discountAmount,
  });

  /// Builds a card straight from the service payload the API returns.
  /// Home sections, recently viewed and book again all send the same shape,
  /// so they all come through here.
  factory ServiceCard.fromJson(Map<String, dynamic> json) {
    final discount = json['discount_info'] as Map<String, dynamic>?;
    return ServiceCard(
      serviceId: json['service_id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      durationMinutes: json['duration_minutes'],
      imageUrl: json['image'],
      categoryId: json['category_id'],
      subcategoryId: json['subcategory_id'],
      categoryName: json['category_name'] ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      finalPrice: discount != null
          ? double.tryParse('${discount['final_price']}')
          : null,
      discountAmount: discount != null
          ? double.tryParse('${discount['discount_amount']}')
          : null,
    );
  }

  @override
  State<ServiceCard> createState() => ServiceCardState();
}

class ServiceCardState extends State<ServiceCard> {
  final _cart = CartService();

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  Future<void> _onAddTap() async {
    // Check for form
    try {
      List<dynamic> forms = await ApiService.getFormByService(
        serviceId: widget.serviceId,
      );
      if (forms.isEmpty && widget.subcategoryId != null) {
        forms = await ApiService.getFormByService(
          subcategoryId: widget.subcategoryId,
        );
      }
      if (forms.isEmpty) {
        forms = await ApiService.getFormByService(
          categoryId: widget.categoryId,
        );
      }

      if (forms.isNotEmpty && mounted) {
        final result = await Navigator.of(context)
            .push<List<Map<String, dynamic>>>(
              MaterialPageRoute(
                builder: (_) => ServiceFormScreen(
                  form: Map<String, dynamic>.from(forms.first),
                  categoryName: widget.categoryName,
                  returnDataOnly: true,
                ),
              ),
            );
        if (result == null) return;

        _cart.setCategoryInfo(
          categoryId: widget.categoryId,
          subcategoryId: widget.subcategoryId,
          categoryName: widget.categoryName,
        );
        _cart.addItem(
          serviceId: widget.serviceId,
          name: widget.name,
          price: widget.price,
          formId: forms.first['id'],
          formData: result,
        );
        return;
      }
    } catch (_) {}

    // No form — add directly
    _cart.setCategoryInfo(
      categoryId: widget.categoryId,
      subcategoryId: widget.subcategoryId,
      categoryName: widget.categoryName,
    );
    _cart.addItem(
      serviceId: widget.serviceId,
      name: widget.name,
      price: widget.price,
    );
  }

  Future<void> _openDetail() async {
    if (!await checkProfileComplete(context)) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          serviceId: widget.serviceId,
          name: widget.name,
          description: widget.description,
          price: widget.price,
          durationMinutes: widget.durationMinutes,
          imageUrl: widget.imageUrl,
          categoryId: widget.categoryId,
          subcategoryId: widget.subcategoryId,
          categoryName: widget.categoryName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qty = _cart.getQuantity(widget.serviceId);

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 110,
                width: double.infinity,
                color: Colors.grey.shade100,
                child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                    ? Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: decodeWidthFor(context, 150),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.image,
                            color: AppColors.textGrey,
                            size: 32,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image,
                          color: AppColors.textGrey,
                          size: 32,
                        ),
                      ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.averageRating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          widget.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '(${widget.totalReviews})',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // Price + Add button
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child:
                        widget.discountAmount != null &&
                            widget.discountAmount! > 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${widget.finalPrice!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '₹${widget.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGrey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '₹${widget.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  qty == 0
                      ? SizedBox(
                          height: 28,
                          child: OutlinedButton(
                            onPressed: _onAddTap,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _cart.removeItem(widget.serviceId),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: _onAddTap,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
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

