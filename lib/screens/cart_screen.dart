import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import 'booking_screen.dart';
import 'service_form_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService();

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadApplicableDiscount();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  Future<void> _loadApplicableDiscount() async {
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

  Future<void> _applyCoupon(String code) async {
    try {
      final result = await ApiService.validateCoupon(
        code: code,
        cartTotal: _cart.totalAmount,
      );
      final amount = double.tryParse('${result['discount_amount']}') ?? 0;
      _cart.setCouponDiscount(amount, code.toUpperCase());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Coupon applied! You saved ₹${amount.toStringAsFixed(0)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _proceedToBooking() {
    final categories = _cart.distinctCategories;

    if (categories.length == 1) {
      // Single category — go to booking screen directly
      final cat = categories.first;
      final items = (cat['items'] as List<CartItem>);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingScreen(
            categoryId: cat['categoryId'],
            categoryName: cat['categoryName'],
            basePrice: items.fold(0.0, (sum, i) => sum + i.total),
            subcategoryId: cat['subcategoryId'],
            cartItems: items.map((i) => i.toJson()).toList(),
          ),
        ),
      );
    } else {
      // Multiple categories — go to booking screen for all
      // Creates one booking per category with same date/time/address
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _MultiBookingScreen(categories: categories),
        ),
      );
    }
  }

  Future<void> _editFormItem(int itemIndex, CartItem item) async {
    if (item.formId == null) return;

    // Fetch the form structure
    try {
      final forms = await ApiService.getFormByService(
        serviceId: item.serviceId,
      );

      // Also try category/subcategory level
      List<dynamic> formList = forms;
      if (formList.isEmpty) {
        formList = await ApiService.getFormByService(
          subcategoryId: item.subcategoryId,
        );
      }
      if (formList.isEmpty) {
        formList = await ApiService.getFormByService(
          categoryId: item.categoryId,
        );
      }

      if (formList.isEmpty || !mounted) return;

      final result = await Navigator.of(context)
          .push<List<Map<String, dynamic>>>(
            MaterialPageRoute(
              builder: (_) => ServiceFormScreen(
                form: Map<String, dynamic>.from(formList.first),
                categoryName: item.categoryName,
                returnDataOnly: true,
                prefillData: item.formData,
              ),
            ),
          );

      if (result != null) {
        _cart.updateItemForm(itemIndex, result);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _cart.groupedByCategory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          if (!_cart.isEmpty)
            TextButton(
              onPressed: () {
                _cart.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: _cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                ...grouped.entries.map((entry) {
                  final categoryName = entry.key;
                  final items = entry.value;
                  final categoryTotal = items.fold(
                    0.0,
                    (sum, i) => sum + i.total,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              '₹${categoryTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Items
                      ...items.asMap().entries.map((itemEntry) {
                        final itemIndex = _cart.items.indexOf(itemEntry.value);
                        final item = itemEntry.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹${item.price.toStringAsFixed(0)} × ${item.quantity} = ₹${item.total.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppColors.textGrey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity controls
                                    if (item.formData != null)
                                      // Form items — delete button only
                                      GestureDetector(
                                        onTap: () => _cart.removeAt(itemIndex),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.red.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red.shade400,
                                            size: 18,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        height: 34,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.primary,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _cart.removeItem(
                                                item.serviceId,
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                ),
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _cart.addItem(
                                                serviceId: item.serviceId,
                                                name: item.name,
                                                price: item.price,
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  size: 18,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                // Form summary
                                if (item.formData != null &&
                                    item.formSummary.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.formSummary,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textGrey,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () =>
                                              _editFormItem(itemIndex, item),
                                          child: const Text(
                                            'Edit',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  );
                }),

                const Divider(height: 24),
                // Coupon input
                _CouponInput(
                  onApply: _applyCoupon,
                  appliedCode: _cart.couponCode,
                  onRemove: () => _cart.clearCoupon(),
                ),
                const SizedBox(height: 16),

                // Discount rows
                if (_cart.autoDiscount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_cart.autoDiscountName} discount',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '-₹${_cart.autoDiscount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                if (_cart.couponDiscount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Coupon (${_cart.couponCode})',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '-₹${_cart.couponDiscount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_cart.finalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                if (_cart.distinctCategories.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_cart.distinctCategories.length} categories — a separate booking will be created for each so the right vendor can be assigned.',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
      bottomSheet: _cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _proceedToBooking,
                    child: Text(
                      'Proceed to Book • ₹${_cart.finalAmount.toStringAsFixed(0)}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// When the cart has items from multiple categories, this screen
/// collects date/time/address ONCE and creates one booking per category.
class _MultiBookingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const _MultiBookingScreen({required this.categories});

  @override
  State<_MultiBookingScreen> createState() => _MultiBookingScreenState();
}

class _MultiBookingScreenState extends State<_MultiBookingScreen> {
  final _cart = CartService();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _addressController = TextEditingController();
  String _profileState = '';
  String _profileDistrict = '';
  String _profilePincode = '';
  String _profilePhone = '';
  double? _locationLat;
  double? _locationLng;
  final _notesController = TextEditingController();
  bool _isLoadingAddress = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadApplicableDiscount();
  }

  Future<void> _loadApplicableDiscount() async {
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

  Future<void> _applyCoupon(String code) async {
    try {
      final result = await ApiService.validateCoupon(
        code: code,
        cartTotal: _cart.totalAmount,
      );
      final amount = double.tryParse('${result['discount_amount']}') ?? 0;
      _cart.setCouponDiscount(amount, code.toUpperCase());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Coupon applied! You saved ₹${amount.toStringAsFixed(0)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _loadAddress() async {
    setState(() => _isLoadingAddress = true);
    try {
      final profile = await ApiService.getMyProfile();
      _addressController.text = (profile['address'] as String?)?.trim() ?? '';
      _profileState = (profile['state'] as String?)?.trim() ?? '';
      _profileDistrict = (profile['district'] as String?)?.trim() ?? '';
      _profilePincode = (profile['pincode'] as String?)?.trim() ?? '';
      _profilePhone = (profile['phone_number'] as String?)?.trim() ?? '';
      final lat = profile['latitude'];
      final lng = profile['longitude'];
      if (lat != null) _locationLat = double.tryParse('$lat');
      if (lng != null) _locationLng = double.tryParse('$lng');
    } catch (_) {}
    if (mounted) setState(() => _isLoadingAddress = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submitAll() async {
    if (_selectedDate == null || _selectedTime == null) {
      setState(() => _errorMessage = 'Please select both a date and a time.');
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please add your address.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      int created = 0;
      for (final cat in widget.categories) {
        final items = (cat['items'] as List<CartItem>);
        // Split the total discount proportionally across categories
        final catSubtotal = items.fold(0.0, (sum, i) => sum + i.total);
        final cartSubtotal = _cart.totalAmount;
        final catDiscount = cartSubtotal > 0
            ? (_cart.totalDiscount * (catSubtotal / cartSubtotal))
            : 0.0;

        await ApiService.createBooking(
          categoryId: cat['categoryId'],
          subcategoryId: cat['subcategoryId'],
          preferredDate: _formatDate(_selectedDate!),
          preferredTime: _formatTime(_selectedTime!),
          notes: _notesController.text.trim(),
          addressText: _addressController.text.trim(),
          addressState: _profileState,
          addressDistrict: _profileDistrict,
          addressPincode: _profilePincode,
          customerPhone: _profilePhone,
          locationLat: _locationLat,
          locationLng: _locationLng,
          servicesJson: items.map((i) => i.toJson()).toList(),
          discountAmount: catDiscount,
          couponCode: _cart.couponCode,
        );
        created++;
      }

      CartService().clear();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Bookings Confirmed'),
          content: Text(
            '$created booking${created > 1 ? 's' : ''} created for '
            '${_formatDate(_selectedDate!)} at ${_selectedTime!.format(context)}.\n\n'
            'A vendor will be assigned to each booking shortly.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // dialog
                Navigator.of(context).pop(); // this screen
                Navigator.of(context).pop(); // cart screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Services')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary
          Text(
            '${widget.categories.length} bookings will be created',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'One booking per category so the right vendor can be assigned to each.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...widget.categories.map((cat) {
            final items = (cat['items'] as List<CartItem>);
            final catTotal = items.fold(0.0, (sum, i) => sum + i.total);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${cat['categoryName']} — ₹${catTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }),
          const SizedBox(height: 20),

          // Date
          ListTile(
            tileColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.calendar_today),
            title: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : _formatDate(_selectedDate!),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),

          // Time
          ListTile(
            tileColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.access_time),
            title: Text(
              _selectedTime == null
                  ? 'Select Time'
                  : _selectedTime!.format(context),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _pickTime,
          ),
          const SizedBox(height: 20),

          // Address
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Your Address',
              hintText: 'Enter your address',
            ),
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Describe the issue (optional)',
              hintText: 'e.g. Kitchen tap has been leaking for 2 days',
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitAll,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirm ${widget.categories.length} Bookings • ₹${_cart.finalAmount.toStringAsFixed(0)}',
                  ),
          ),
        ],
      ),
    );
  }
}

class _CouponInput extends StatefulWidget {
  final Function(String) onApply;
  final String appliedCode;
  final VoidCallback onRemove;

  const _CouponInput({
    required this.onApply,
    required this.appliedCode,
    required this.onRemove,
  });

  @override
  State<_CouponInput> createState() => _CouponInputState();
}

class _CouponInputState extends State<_CouponInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _showInput = false;

  @override
  Widget build(BuildContext context) {
    // Coupon already applied — show the green applied chip
    if (widget.appliedCode.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.appliedCode} applied',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onRemove,
              child: const Icon(Icons.close, color: Colors.green, size: 20),
            ),
          ],
        ),
      );
    }

    // Collapsed state — just an "Add coupon" link
    if (!_showInput) {
      return GestureDetector(
        onTap: () => setState(() => _showInput = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Add coupon code',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
    }

    // Expanded state — show the input field + Apply
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter coupon code',
              prefixIcon: const Icon(Icons.local_offer_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _showInput = false;
                  _controller.clear();
                }),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onApply(_controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
