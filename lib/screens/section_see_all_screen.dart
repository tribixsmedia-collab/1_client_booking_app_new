import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import '../utils/profile_gate.dart';
import '../screens/service_detail_screen.dart';
import '../screens/service_form_screen.dart';

class SectionSeeAllScreen extends StatefulWidget {
  final int sectionId;
  final String title;
  final String subtitle;

  const SectionSeeAllScreen({
    super.key,
    required this.sectionId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<SectionSeeAllScreen> createState() => _SectionSeeAllScreenState();
}

class _SectionSeeAllScreenState extends State<SectionSeeAllScreen> {
  final _cart = CartService();
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final data = await ApiService.getHomeSectionFull(widget.sectionId);
      if (mounted) {
        setState(() {
          _items = data['items'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  Future<void> _onAddTap(Map<String, dynamic> item) async {
    if (!await checkProfileComplete(context)) return;

    final serviceId = item['service_id'] as int;
    final categoryId = item['category_id'] as int;
    final subcategoryId = item['subcategory_id'];
    final categoryName = item['category_name'] as String? ?? '';
    final name = item['name'] as String;
    final price = double.tryParse('${item['price']}') ?? 0;

    try {
      List<dynamic> forms = await ApiService.getFormByService(
        serviceId: serviceId,
      );
      if (forms.isEmpty && subcategoryId != null) {
        forms = await ApiService.getFormByService(subcategoryId: subcategoryId);
      }
      if (forms.isEmpty) {
        forms = await ApiService.getFormByService(categoryId: categoryId);
      }

      if (forms.isNotEmpty && mounted) {
        final result = await Navigator.of(context)
            .push<List<Map<String, dynamic>>>(
              MaterialPageRoute(
                builder: (_) => ServiceFormScreen(
                  form: Map<String, dynamic>.from(forms.first),
                  categoryName: categoryName,
                  returnDataOnly: true,
                ),
              ),
            );
        if (result == null) return;

        _cart.setCategoryInfo(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          categoryName: categoryName,
        );
        _cart.addItem(
          serviceId: serviceId,
          name: name,
          price: price,
          formId: forms.first['id'],
          formData: result,
        );
        return;
      }
    } catch (_) {}

    _cart.setCategoryInfo(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      categoryName: categoryName,
    );
    _cart.addItem(serviceId: serviceId, name: name, price: price);
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    if (!await checkProfileComplete(context)) return;
    if (!mounted) return;

    final discountInfo = item['discount_info'] as Map<String, dynamic>?;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          serviceId: item['service_id'],
          name: item['name'],
          description: item['description'] ?? '',
          price: double.tryParse('${item['price']}') ?? 0,
          durationMinutes: item['duration_minutes'],
          imageUrl: item['image'],
          categoryId: item['category_id'],
          subcategoryId: item['subcategory_id'],
          categoryName: item['category_name'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18)),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('No services available'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final serviceId = item['service_id'] as int;
                final name = item['name'] as String;
                final price = double.tryParse('${item['price']}') ?? 0;
                final imageUrl = item['image'] as String?;
                final rating =
                    (item['average_rating'] as num?)?.toDouble() ?? 0;
                final totalReviews = item['total_reviews'] as int? ?? 0;
                final discountInfo =
                    item['discount_info'] as Map<String, dynamic>?;
                final finalPrice = discountInfo != null
                    ? double.tryParse('${discountInfo['final_price']}')
                    : null;
                final qty = _cart.getQuantity(serviceId);

                return GestureDetector(
                  onTap: () => _openDetail(Map<String, dynamic>.from(item)),
                  child: Container(
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
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
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
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (rating > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '($totalReviews)',
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
                        // Price + Add
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: finalPrice != null && finalPrice < price
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '₹${finalPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '₹${price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textGrey,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '₹${price.toStringAsFixed(0)}',
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
                                        onPressed: () => _onAddTap(
                                          Map<String, dynamic>.from(item),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          side: const BorderSide(
                                            color: AppColors.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                                            onTap: () =>
                                                _cart.removeItem(serviceId),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
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
                                            onTap: () => _onAddTap(
                                              Map<String, dynamic>.from(item),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
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
              },
            ),
    );
  }
}
