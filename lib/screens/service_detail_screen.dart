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
import '../utils/zone_gate.dart';
import '../models/service_pricing.dart';
import 'create_tender_screen.dart';
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

  /// How [price] becomes an amount. Defaults to a flat price, so a caller
  /// that has not been taught about pricing types behaves as it always did.
  final ServicePricing? pricing;

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
    this.pricing,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final _cart = CartService();

  ServicePricing get _pricing =>
      widget.pricing ?? ServicePricing.fixed(widget.price);

  /// What the customer typed into the measured-quantity box — hours, square
  /// feet, kilos. Only used for the pricing types that ask for one.
  final _quantityController = TextEditingController(text: '1');

  double get _measuredQuantity =>
      double.tryParse(_quantityController.text.trim()) ?? 0;
  Map<String, dynamic>? _reviewData;
  bool _isLoadingReviews = true;
  Map<String, dynamic>? _discountInfo;
  double _discountedPrice = 0;
  List<dynamic> _proVendors = [];
  bool _isLoadingPros = true;

  // Whether this service can actually be had where the customer lives.
  // Null until the answer lands, and null forever for a guest we cannot
  // place — which lets the booking through rather than blocking it.
  Map<String, String>? _customerArea;
  Map<String, dynamic>? _zone;
  bool _isCheckingZone = true;

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
    _loadZone();
    // Feeds the "Recently viewed" row on the home page.
    ApiService.recordServiceView(widget.serviceId);
  }

  /// Asks whether anyone works this service in the customer's own state, and
  /// loads the pros with that state in hand so the row only offers vendors
  /// who could actually turn up.
  ///
  /// Safe to call again: signing in at the booking gate is exactly when a
  /// customer we could not place becomes one we can.
  Future<void> _loadZone() async {
    final area = await ApiService.getMyArea();
    final zone = await ApiService.getServiceAvailability(
      serviceId: widget.serviceId,
      state: area?['state'],
      district: area?['district'],
    );

    if (!mounted) return;
    setState(() {
      _customerArea = area;
      _zone = zone;
      _isCheckingZone = false;
    });

    await _loadProVendors();
  }

  /// True only when we know where the customer is and know nobody covers it.
  /// A failed call, a guest, a profile with no state — none of those block a
  /// booking.
  bool get _zoneBlocked => _zone?['available'] == false;

  /// The vendors offered instead when nobody covers the customer's state.
  List<dynamic> get _vendorsElsewhere =>
      (_zone?['vendors_elsewhere'] as List<dynamic>?) ?? [];

  /// Re-checks the zone if we never knew where the customer was, then says
  /// whether the booking may go on.
  Future<bool> _zoneAllowsBooking() async {
    if (_customerArea == null) await _loadZone();
    return !_zoneBlocked;
  }

  /// Pros who cover this service, in the customer's state when we know it.
  Future<void> _loadProVendors() async {
    final vendors = await ApiService.getProVendors(
      serviceId: widget.serviceId,
      state: _customerArea?['state'],
      district: _customerArea?['district'],
    );
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

  void _showZoneBlockedDialog() {
    showZoneBlockedDialog(
      context,
      zone: _zone ?? const {},
      serviceName: widget.name,
    );
  }

  /// Where the customer is, as the server spells it.
  String _zoneStateName() => zoneStateName(_zone);

  /// Puts the unit back on a figure we formatted ourselves, so a discounted
  /// rate still reads as "₹12 / sq ft" rather than a bare "₹12".
  String _withUnit(String money) =>
      _pricing.unitLabel.isEmpty ? money : '$money / ${_pricing.unitLabel}';

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

    // Zone gate. It runs after the profile gate on purpose: a guest has no
    // state until they sign in, and the state is what this question is about.
    if (!await _zoneAllowsBooking()) {
      if (mounted) _showZoneBlockedDialog();
      return;
    }

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
          quantity: _orderQuantity,
          pricingType: _pricing.type,
          unitLabel: _pricing.unitLabel,
          needsQuantity: _pricing.needsQuantity,
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
      quantity: _orderQuantity,
      pricingType: _pricing.type,
      unitLabel: _pricing.unitLabel,
      needsQuantity: _pricing.needsQuantity,
    );
  }

  /// How much is being ordered: what the customer measured for a per-unit
  /// service, or one more of a counted one.
  double get _orderQuantity =>
      _pricing.needsQuantity ? _measuredQuantity : 1;

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _quantityController.dispose();
    super.dispose();
  }

  /// A quote-only service cannot be added to a cart — there is no price to
  /// add. It goes to the tender flow instead, where the customer posts the
  /// job and vendors bid on it.
  Future<void> _onRequestQuoteTap() async {
    if (!await checkProfileComplete(context)) return;
    if (!await _zoneAllowsBooking()) {
      if (mounted) _showZoneBlockedDialog();
      return;
    }
    if (!mounted) return;

    // The form opens on this service: its category and subcategory are the
    // type of work, and the project type is whatever the admin set on it.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateTenderScreen(
          seed: QuoteSeed(
            categoryId: widget.categoryId,
            subcategoryId: widget.subcategoryId,
            projectType: _pricing.tenderProjectType,
            serviceName: widget.name,
          ),
        ),
      ),
    );
  }

  /// The box that takes the order.
  ///
  /// Three shapes, decided by the pricing type: a quote request when there is
  /// no price to charge, a number box when the price is a rate that has to be
  /// multiplied by something the customer measures, and the familiar +/-
  /// stepper when it is simply counted.
  Widget _buildBookingBox(double qty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _pricing.isQuoteOnly
          ? _buildQuoteRequest()
          : _pricing.needsQuantity
          ? _buildMeasuredOrder()
          : _buildCountedOrder(qty),
    );
  }

  /// No price to add to a cart — the customer posts the job and vendors bid.
  Widget _buildQuoteRequest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This service is priced after a look',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Post what you need and vendors will send you their quotes. You '
          'choose the one you want.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _onRequestQuoteTap,
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: const Text('Request a quote'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A rate times something the customer measures: hours, square feet, kilos.
  Widget _buildMeasuredOrder() {
    final quantity = _measuredQuantity;
    final total = widget.price * quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _pricing.measureLabel,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: _pricing.allowsDecimal,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: _pricing.unitLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                quantity > 0
                    ? '= ₹${total.toStringAsFixed(0)}'
                    : 'Enter ${_pricing.measureLabel.toLowerCase()}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: quantity > 0 ? AppColors.primary : AppColors.textGrey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: quantity > 0 ? _onAddTap : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _cart.getQuantity(widget.serviceId) > 0
                  ? 'Update'
                  : 'Add',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The familiar stepper, for a price that is simply counted.
  Widget _buildCountedOrder(double qty) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'per unit',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ),
        qty == 0
            ? SizedBox(
                width: 100,
                height: 40,
                child: OutlinedButton(
                  onPressed: _onAddTap,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => _cart.removeItem(widget.serviceId),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Text(
                      formatQuantity(qty),
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
    );
  }

  /// Where this service stands for this customer: a quiet confirmation when
  /// somebody covers their state, and the "no vendor in your zone" notice
  /// with the out-of-state vendors underneath it when nobody does.
  ///
  /// Silent while the answer is still in the air, and silent for anyone we
  /// cannot place, so a guest browsing sees the page exactly as before.
  Widget _buildZoneNotice() {
    if (_isCheckingZone || _zone == null) return const SizedBox.shrink();
    if (_zone!['state_known'] != true) return const SizedBox.shrink();

    if (!_zoneBlocked) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 15, color: Colors.green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Available in ${_zoneStateName()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final elsewhere = _vendorsElsewhere;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE0A3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 20,
                color: Color(0xFFE65100),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No vendor in your zone',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A3E00),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nobody does this service in ${_zoneStateName()} yet, so '
                      'it cannot be booked here for now.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF7A3E00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (elsewhere.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Vendors in other areas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'These vendors do this work, but not where you are. The state and '
            'district each one covers from is on their card.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(elsewhere.length, (index) {
            final vendor = Map<String, dynamic>.from(elsewhere[index]);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == elsewhere.length - 1 ? 0 : 12,
              ),
              // No Book action: this vendor has said they do not work where
              // the customer is, and the card is here to say who does this
              // work and where, not to take a booking they cannot serve.
              // Only a pro has a profile page to open; the rest are inert.
              child: ProVendorListTile(
                vendor: vendor,
                onTap: vendor['is_pro'] == true
                    ? () => _openProProfile(vendor)
                    : null,
              ),
            );
          }),
        ],
      ],
    );
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
                        // A discount is struck through the rate, not the
                        // total: on a per-unit service the rate is what the
                        // customer is comparing.
                        if (_discountInfo != null && !_pricing.isQuoteOnly) ...[
                          Text(
                            _withUnit(
                              '₹${_discountedPrice.toStringAsFixed(0)}',
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                            _pricing.priceLabel,
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

                    _buildZoneNotice(),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    _buildBookingBox(qty),

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
