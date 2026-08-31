import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/review_list_widget.dart';
import '../widgets/pro_vendor_card.dart';
import 'pro_vendor_detail_screen.dart';
import 'service_form_screen.dart';
import '../utils/profile_gate.dart';
import 'cart_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final int serviceId;
  final String name;
  final String description;
  final double price;
  final int? durationMinutes;
  final String? imageUrl;
  final int categoryId;
  final int? subcategoryId;
  final String categoryName;

  const ServiceDetailScreen({
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
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _cart = CartService();
  Map<String, dynamic>? _reviewData;
  bool _isLoadingReviews = true;
  Map<String, dynamic>? _discountInfo;
  double _discountedPrice = 0;
  List<dynamic> _proVendors = [];
  bool _isLoadingPros = true;

  @override
  void initState() {
    super.initState();
    _cart.setCategoryInfo(
      categoryId: widget.categoryId,
      subcategoryId: widget.subcategoryId,
      categoryName: widget.categoryName,
    );
    _cart.addListener(_onCartChanged);
    _loadReviews();
    _loadDiscount();
    _loadProVendors();
    // Feeds the "Recently viewed" row on the home page.
    ApiService.recordServiceView(widget.serviceId);
  }

  /// Pros who cover this service's category, so the customer can ask for a
  /// particular one while booking it.
  Future<void> _loadProVendors() async {
    final vendors = await ApiService.getProVendors(serviceId: widget.serviceId);
    if (mounted) {
      setState(() {
        _proVendors = vendors;
        _isLoadingPros = false;
      });
    }
  }

  /// Tapping "Book" on a pro records the request; tapping it again on the
  /// pro already chosen takes it back off.
  Future<void> _onProBookTap(Map<String, dynamic> vendor) async {
    final vendorId = vendor['id'] as int;

    if (_cart.preferredVendorId == vendorId) {
      _cart.clearPreferredVendor();
      _showSnack('Removed your pro request.');
      return;
    }

    if (!await checkProfileComplete(context)) return;
    if (!mounted) return;

    final name = (vendor['name'] as String?) ?? '';
    _cart.setPreferredVendor(vendorId, name, categoryIds: [widget.categoryId]);
    _showSnack('$name will be requested for this booking.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openProProfile(Map<String, dynamic> vendor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProVendorDetailScreen(
          vendorId: vendor['id'] as int,
          preview: vendor,
          bookServiceId: widget.serviceId,
          bookServiceName: widget.name,
        ),
      ),
    );
  }

  int _lastItemCount = -1;

  void _onCartChanged() {
    if (mounted) setState(() {});
    // Only refresh discount when the number of items changes (not on discount updates)
    if (_cart.totalItems != _lastItemCount) {
      _lastItemCount = _cart.totalItems;
      _refreshCartDiscount();
    }
  }

  Future<void> _refreshCartDiscount() async {
    if (_cart.isEmpty) return;
    try {
      final items = _cart.items
          .map(
            (i) => {
              'service_id': i.serviceId,
              'category_id': i.categoryId,
              'subcategory_id': i.subcategoryId,
              'price': i.price,
              'qty': i.quantity,
            },
          )
          .toList();
      final result = await ApiService.getApplicableDiscount(items: items);
      final discount = result['discount'];
      final amount = double.tryParse('${result['discount_amount']}') ?? 0;
      if (discount != null && amount > 0) {
        _cart.setAutoDiscount(amount, discount['name'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _onAddTap() async {
    // Profile-completion gate
    if (!await checkProfileComplete(context)) return;

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
    _cart.addItem(
      serviceId: widget.serviceId,
      name: widget.name,
      price: widget.price,
    );
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  /// The pro vendors who can take this service on, listed under the reviews.
  Widget _buildProVendors() {
    // Nothing to show until the call lands, and nothing to apologise for if
    // no pro covers this category — the section simply is not there.
    if (_isLoadingPros || _proVendors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        Row(
          children: [
            const Icon(Icons.verified, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text(
              'Book with a Pro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick a pro for this service. We will pass your request on when '
          'assigning the job.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),

        ...List.generate(_proVendors.length, (index) {
          final vendor = Map<String, dynamic>.from(_proVendors[index]);
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _proVendors.length - 1 ? 0 : 12,
            ),
            child: ProVendorListTile(
              vendor: vendor,
              isSelected: _cart.preferredVendorId == vendor['id'],
              onTap: () => _openProProfile(vendor),
              onBook: () => _onProBookTap(vendor),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final qty = _cart.getQuantity(widget.serviceId);

    return Scaffold(
      body: DesktopCentered(
        child: CustomScrollView(
          slivers: [
            // Hero image header
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                      Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey.shade200),
                      )
                    else
                      Container(color: Colors.grey.shade200),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Title on image
                    Positioned(
                      left: 20,
                      bottom: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service name & price
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!_isLoadingReviews &&
                            _reviewData != null &&
                            (_reviewData!['total_reviews'] as int? ?? 0) >
                                0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            ((_reviewData!['average_rating'] as num?) ?? 0)
                                .toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${_reviewData!['total_reviews']})',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_discountInfo != null) ...[
                          // Discounted price
                          Text(
                            '₹${_discountedPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Original price struck through
                          Text(
                            '₹${widget.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textGrey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ] else
                          Text(
                            '₹${widget.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        if (widget.durationMinutes != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${widget.durationMinutes} mins',
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Discount badge
                    if (_discountInfo != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_offer,
                              color: Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _discountInfo!['name'] ?? 'Discount applied',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      widget.categoryName,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Add to cart section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text(
                                //   '₹${widget.price.toStringAsFixed(0)}',
                                //   style: const TextStyle(
                                //     fontSize: 18,
                                //     fontWeight: FontWeight.bold,
                                //   ),
                                // ),
                                const SizedBox(height: 2),
                                const Text(
                                  'per unit',
                                  style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          qty == 0
                              ? SizedBox(
                                  width: 100,
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: _onAddTap,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Add',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 100,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            _cart.removeItem(widget.serviceId),
                                        child: const Icon(
                                          Icons.remove,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      Text(
                                        '$qty',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _onAddTap,
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),

                    if (widget.description.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Description / Highlights
                      const Row(
                        children: [
                          Text('✨ ', style: TextStyle(fontSize: 16)),
                          Text(
                            'HIGHLIGHTS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],

                    _buildProVendors(),

                    // Reviews section
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    const Text(
                      'Ratings & Reviews',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_isLoadingReviews)
                      const Center(child: CircularProgressIndicator())
                    else if (_reviewData != null &&
                        (_reviewData!['total_reviews'] as int? ?? 0) > 0)
                      ReviewListWidget(
                        averageRating:
                            ((_reviewData!['average_rating'] as num?) ?? 0)
                                .toDouble(),
                        totalReviews:
                            _reviewData!['total_reviews'] as int? ?? 0,
                        reviews:
                            _reviewData!['reviews'] as List<dynamic>? ?? [],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No reviews yet. Be the first to review!',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom bar
      // Null when the cart is empty, so the wrapper has to sit inside the
      // branch that actually builds a bar.
      bottomSheet: _cart.isEmpty
          ? null
          : DesktopCentered(
              fillHeight: false,
              maxWidth: kDesktopContentWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Text(
                        '${_cart.totalItems} item${_cart.totalItems > 1 ? 's' : ''} | ₹${_cart.finalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _loadReviews() async {
    try {
      // Try service-specific reviews first, fall back to category reviews
      var data = await ApiService.getIndividualServiceReviews(widget.serviceId);
      if ((data['total_reviews'] as int? ?? 0) == 0) {
        data = await ApiService.getServiceReviews(widget.categoryId);
      }
      if (mounted)
        setState(() {
          _reviewData = data;
          _isLoadingReviews = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _loadDiscount() async {
    try {
      final result = await ApiService.getApplicableDiscount(
        items: [
          {
            'service_id': widget.serviceId,
            'category_id': widget.categoryId,
            'subcategory_id': widget.subcategoryId,
            'price': widget.price,
            'qty': 1,
          },
        ],
      );
      final discount = result['discount'];
      final amount = double.tryParse('${result['discount_amount']}') ?? 0;
      if (discount != null && amount > 0 && mounted) {
        setState(() {
          _discountInfo = discount;
          _discountedPrice = (widget.price - amount).clamp(0, widget.price);
        });
      }
    } catch (_) {}
  }
}
