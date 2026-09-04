import '../models/service_pricing.dart';
import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'service_form_screen.dart';
import 'service_detail_screen.dart';
import '../utils/profile_gate.dart';
import '../utils/zone_gate.dart';

class ServiceListScreen extends StatefulWidget {
  final int categoryId;
  final int? subcategoryId;
  final String title;
  final List<dynamic> services;

  const ServiceListScreen({
    super.key,
    required this.categoryId,
    this.subcategoryId,
    required this.title,
    required this.services,
  });

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final _cart = CartService();
  // Cache: serviceId -> form data (null = no form, Map = has form)
  final Map<int, Map<String, dynamic>?> _formCache = {};
  bool _isLoadingForms = true;

  @override
  void initState() {
    super.initState();
    _cart.setCategoryInfo(
      categoryId: widget.categoryId,
      subcategoryId: widget.subcategoryId,
      categoryName: widget.title,
    );
    _cart.addListener(_onCartChanged);
    _preloadForms();

    // A list of one is no choice at all, so go straight to the service.
    // Replacing rather than pushing keeps Back going where the customer came
    // from instead of to a one-row list.
    if (widget.services.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openServiceDetail(widget.services.first, replace: true);
      });
    }
  }

  Future<void> _preloadForms() async {
    // Check for category-level or subcategory-level form
    try {
      final forms = await ApiService.getFormByService(
        subcategoryId: widget.subcategoryId,
        categoryId: widget.subcategoryId == null ? widget.categoryId : null,
      );

      if (forms.isNotEmpty) {
        // This form applies to all services in this category/subcategory
        final form = Map<String, dynamic>.from(forms.first);
        for (final svc in widget.services) {
          _formCache[svc['id'] as int] = form;
        }
      }
    } catch (_) {}

    // Check for service-level forms
    for (final svc in widget.services) {
      final svcId = svc['id'] as int;
      if (_formCache.containsKey(svcId)) continue;

      try {
        final forms = await ApiService.getFormByService(serviceId: svcId);
        _formCache[svcId] = forms.isNotEmpty
            ? Map<String, dynamic>.from(forms.first)
            : null;
      } catch (_) {
        _formCache[svcId] = null;
      }
    }

    if (mounted) setState(() => _isLoadingForms = false);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  /// Opens the service. Also where a per-unit or quote-only row sends the
  /// customer, since neither can be ordered from a list row.
  ///
  /// The one place this screen is built, so its pricing cannot be passed on
  /// one route and forgotten on another -- which is exactly how a quote
  /// service reached here once showing a price instead of "Price on request".
  void _openServiceDetail(Map<String, dynamic> svc, {bool replace = false}) {
    final price = double.tryParse('${svc['price']}') ?? 0;
    final route = MaterialPageRoute(
      builder: (_) => ServiceDetailScreen(
        pricing: ServicePricing.fromJson(svc, price),
        serviceId: svc['id'],
        name: svc['name'],
        description: svc['description'] ?? '',
        price: price,
        durationMinutes: svc['duration_minutes'],
        imageUrl: svc['image'],
        categoryId: widget.categoryId,
        subcategoryId: widget.subcategoryId,
        categoryName: widget.title,
      ),
    );

    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  Future<void> _onAddTap(Map<String, dynamic> svc) async {
    // Profile-completion gate
    if (!await checkProfileComplete(context)) return;

    final svcId = svc['id'] as int;
    final name = svc['name'] as String;
    final price = double.tryParse('${svc['price']}') ?? 0;
    final pricing = ServicePricing.fromJson(svc, price);

    // A list row has no room to ask how many square feet, and a quote has no
    // price to add at all. Both open the service, which is where those are
    // handled.
    if (pricing.needsQuantity || pricing.isQuoteOnly) {
      if (mounted) _openServiceDetail(svc);
      return;
    }

    if (!await checkServiceZone(context, serviceId: svcId, serviceName: name)) {
      return;
    }
    if (!mounted) return;

    final form = _formCache[svcId];

    if (form != null) {
      // Has form — open it first
      final result = await Navigator.of(context)
          .push<List<Map<String, dynamic>>>(
            MaterialPageRoute(
              builder: (_) => ServiceFormScreen(
                form: form,
                categoryName: widget.title,
                returnDataOnly: true,
              ),
            ),
          );

      if (result == null) return; // cancelled

      _cart.addItem(
        serviceId: svcId,
        name: name,
        price: price,
        pricingType: pricing.type,
        unitLabel: pricing.unitLabel,
        needsQuantity: pricing.needsQuantity,
        formId: form['id'],
        formData: result,
      );
    } else {
      // No form — add directly
      _cart.addItem(
        serviceId: svcId,
        name: name,
        price: price,
        pricingType: pricing.type,
        unitLabel: pricing.unitLabel,
        needsQuantity: pricing.needsQuantity,
      );
    }
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: DesktopCentered(
        child: widget.services.isEmpty
            ? const Center(child: Text('No services available yet.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: widget.services.length,
                itemBuilder: (context, index) {
                  final svc = widget.services[index];
                  final svcId = svc['id'] as int;
                  final name = svc['name'] as String;
                  final price = double.tryParse('${svc['price']}') ?? 0;
                  final desc = (svc['description'] as String?) ?? '';
                  final imageUrl = svc['image'] as String?;
                  final duration = svc['duration_minutes'] as int?;
                  final rating =
                      (svc['average_rating'] as num?)?.toDouble() ?? 0;
                  final reviews = (svc['total_reviews'] as int?) ?? 0;
                  final qty = _cart.getQuantity(svcId);
                  final hasForm = _formCache[svcId] != null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    // The whole row opens the service. Tapping a card and
                    // getting nothing because only the title was live is not
                    // something a customer should have to learn; the Add
                    // button sits on top and keeps its own tap.
                    child: InkWell(
                      onTap: () => _openServiceDetail(svc),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ServicePricing.fromJson(
                                      svc,
                                      price,
                                    ).priceLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  // Rating and duration share a line: two
                                  // small facts, and the card has more room
                                  // across than down.
                                  if (reviews > 0 || duration != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (reviews > 0) ...[
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 15,
                                            color: Color(0xFFFFB300),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${rating.toStringAsFixed(1)} '
                                            '($reviews)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                        ],
                                        if (reviews > 0 && duration != null)
                                          const Text(
                                            '  •  ',
                                            style: TextStyle(
                                              color: AppColors.textGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (duration != null)
                                          Text(
                                            '$duration mins',
                                            style: const TextStyle(
                                              color: AppColors.textGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      desc,
                                      // Two lines: enough to say what the
                                      // service is, not enough to push the
                                      // next card off the screen.
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Image + Add button
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 90,
                                    height: 80,
                                    color: Colors.grey.shade100,
                                    child:
                                        imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.image,
                                                  color: AppColors.textGrey,
                                                ),
                                          )
                                        : const Icon(
                                            Icons.image,
                                            color: AppColors.textGrey,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Add button — always shows "Add" for form services
                                // (each add opens form for unique config)
                                SizedBox(
                                  width: 90,
                                  height: 34,
                                  child: hasForm
                                      ? OutlinedButton(
                                          onPressed: () => _onAddTap(svc),
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Add',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (qty > 0) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    formatQuantity(qty),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        )
                                      : qty == 0
                                      ? OutlinedButton(
                                          onPressed: () => _onAddTap(svc),
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Add',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              GestureDetector(
                                                onTap: () =>
                                                    _cart.removeItem(svcId),
                                                child: const Icon(
                                                  Icons.remove,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              Text(
                                                formatQuantity(qty),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => _onAddTap(svc),
                                                child: const Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      // Bottom cart bar
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
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          '${_cart.totalItems} item${_cart.totalItems > 1 ? 's' : ''} | ₹${_cart.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
            ),
    );
  }
}
