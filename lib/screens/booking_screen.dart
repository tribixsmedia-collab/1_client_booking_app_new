import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../services/cart_service.dart';
import 'booking_detail_screen.dart';

class BookingScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final dynamic basePrice;
  final int? subcategoryId;
  final List<Map<String, dynamic>>? cartItems;
  final int? formSubmissionId;

  const BookingScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.basePrice,
    this.subcategoryId,
    this.cartItems,
    this.formSubmissionId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _profileAddress = '';
  String _profileState = '';
  String _profileDistrict = '';
  String _profilePincode = '';
  String _profilePhone = '';

  bool _isLoadingProfile = true;
  bool _isAddressEditable = false;
  bool _isSubmitting = false;
  bool _isCheckingForm = false;
  double? _latitude;
  double? _longitude;
  int? _formSubmissionId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _formSubmissionId = widget.formSubmissionId;
    _loadProfileAndCheckForm();
  }

  Future<void> _loadProfileAndCheckForm() async {
    setState(() {
      _isLoadingProfile = true;
      _isCheckingForm = true;
    });

    // Load profile
    try {
      final profile = await ApiService.getMyProfile();
      _profileAddress = (profile['address'] as String?)?.trim() ?? '';
      _profileState = (profile['state'] as String?)?.trim() ?? '';
      _profileDistrict = (profile['district'] as String?)?.trim() ?? '';
      _profilePincode = (profile['pincode'] as String?)?.trim() ?? '';
      _profilePhone = (profile['phone_number'] as String?)?.trim() ?? '';
      final lat = profile['latitude'];
      final lng = profile['longitude'];
      if (lat != null) _latitude = double.tryParse('$lat');
      if (lng != null) _longitude = double.tryParse('$lng');
      _addressController.text = _profileAddress;
    } catch (_) {}

    if (mounted) setState(() => _isLoadingProfile = false);

    if (mounted) setState(() => _isCheckingForm = false);
  }

  String get _fullAddress {
    final parts = <String>[];
    if (_addressController.text.trim().isNotEmpty) {
      parts.add(_addressController.text.trim());
    }
    if (_profileDistrict.isNotEmpty) parts.add(_profileDistrict);
    if (_profileState.isNotEmpty) parts.add(_profileState);
    if (_profilePincode.isNotEmpty) parts.add(_profilePincode);
    return parts.join(', ');
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

  Future<void> _submitBooking() async {
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
      final cart = CartService();
      final booking = await ApiService.createBooking(
        categoryId: widget.categoryId,
        subcategoryId: widget.subcategoryId,
        formSubmissionId: _formSubmissionId,
        preferredDate: _formatDate(_selectedDate!),
        preferredTime: _formatTime(_selectedTime!),
        notes: _notesController.text.trim(),
        addressText: _addressController.text.trim(),
        addressState: _profileState,
        addressDistrict: _profileDistrict,
        addressPincode: _profilePincode,
        customerPhone: _profilePhone,
        locationLat: _latitude,
        locationLng: _longitude,
        servicesJson: widget.cartItems,
        discountAmount: cart.totalDiscount,
        couponCode: cart.couponCode,
      );

      if (!mounted) return;

      final bookingId = booking['id'];
      CartService().clear();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Booking Confirmed'),
          content: Text(
            'Your ${widget.categoryName} booking is confirmed for '
            '${_formatDate(_selectedDate!)} at ${_selectedTime!.format(context)}.\n\n'
            'A vendor will be assigned to you shortly.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                // Pop back to the root (home), then open booking detail
                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(booking: booking),
                  ),
                );
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
    if (_isCheckingForm || _isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(title: Text('Book ${widget.categoryName}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.categoryName}')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Text(
              widget.categoryName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Starting from ₹${widget.basePrice}',
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 24),

            // Date picker
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

            // Time picker
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

            // Address section
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 20,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Service Address',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Address display card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address line
                  if (!_isAddressEditable) ...[
                    Text(
                      _addressController.text.isNotEmpty
                          ? _addressController.text
                          : 'No address set',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // District, State, Pincode
                    if (_profileDistrict.isNotEmpty ||
                        _profileState.isNotEmpty ||
                        _profilePincode.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (_profileDistrict.isNotEmpty) _profileDistrict,
                          if (_profileState.isNotEmpty) _profileState,
                          if (_profilePincode.isNotEmpty) _profilePincode,
                        ].join(', '),
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isAddressEditable = true),
                      child: const Text(
                        'Click to edit address',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Editable address
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter your address',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (_profileDistrict.isNotEmpty)
                                'District: $_profileDistrict',
                              if (_profileState.isNotEmpty)
                                'State: $_profileState',
                              if (_profilePincode.isNotEmpty)
                                'Pincode: $_profilePincode',
                            ].join(' • '),
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _isAddressEditable = false),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

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
              onPressed: _isSubmitting ? null : _submitBooking,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
