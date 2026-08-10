import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/booking_timeline.dart';
import 'review_screen.dart';
import '../widgets/review_list_widget.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Map<String, dynamic> _booking;
  bool _isCancelling = false;
  Map<String, dynamic>? _reviewData;
  bool _isLoadingReview = true;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _loadReview();
  }

  Future<void> _loadReview() async {
    try {
      final data = await ApiService.getBookingReview(_booking['id']);
      if (mounted)
        setState(() {
          _reviewData = data;
          _isLoadingReview = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _openReviewScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          bookingId: _booking['id'],
          categoryName: _booking['category_name'] ?? '',
          vendorName: _booking['vendor_name'],
        ),
      ),
    );
    if (result == true) {
      _loadReview();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await ApiService.cancelBooking(_booking['id']);
      setState(() {
        _booking['status'] = 'CANCELLED';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking['status'] ?? 'PENDING';
    final categoryName = _booking['category_name'] ?? '';
    final subcategoryName = _booking['subcategory_name'];
    final vendorName = _booking['vendor_name'];
    final date = _booking['preferred_date'] ?? '';
    final time = _booking['preferred_time'] ?? '';
    final notes = _booking['notes'] ?? '';
    final address = _booking['address_text'] ?? '';
    final state = _booking['address_state'] ?? '';
    final district = _booking['address_district'] ?? '';
    final pincode = _booking['address_pincode'] ?? '';
    final phone = _booking['customer_phone'] ?? '';
    final amount = _booking['amount'] ?? '0';
    final paymentStatus = _booking['payment_status'] ?? 'PENDING';
    final servicesJson = _booking['services_json'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('Booking #${_booking['id']}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Service info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (subcategoryName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subcategoryName,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (servicesJson.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(),
                  ...servicesJson.map((svc) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${svc['name']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '×${svc['qty']} — ₹${svc['price']}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Schedule
          _InfoRow(icon: Icons.calendar_today, label: 'Date', value: date),
          _InfoRow(icon: Icons.access_time, label: 'Time', value: time),
          if (vendorName != null)
            _InfoRow(icon: Icons.person, label: 'Vendor', value: vendorName),
          if (address.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on,
              label: 'Address',
              value: [
                address,
                if (district.isNotEmpty) district,
                if (state.isNotEmpty) state,
                if (pincode.isNotEmpty) pincode,
              ].join(', '),
            ),
          if (phone.isNotEmpty)
            _InfoRow(icon: Icons.phone, label: 'Phone', value: phone),
          if (notes.isNotEmpty)
            _InfoRow(icon: Icons.notes, label: 'Notes', value: notes),

          // Amount
          if (double.tryParse('$amount') != null &&
              double.parse('$amount') > 0) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.payment,
              label: 'Amount',
              value: '₹$amount ($paymentStatus)',
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Timeline
          const Text(
            'Tracking',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),

          BookingTimeline(
            status: status,
            paymentStatus: paymentStatus,
            createdAt: _booking['created_at'],
            assignedAt: _booking['assigned_at'],
            completedAt: _booking['completed_at'],
          ),

          const SizedBox(height: 24),
          // Review section
          if (status == 'COMPLETED') ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            if (_isLoadingReview)
              const Center(child: CircularProgressIndicator())
            else if (_reviewData != null &&
                _reviewData!['reviewed'] != false &&
                _reviewData!['rating'] != null) ...[
              // Already reviewed — show the review
              const Text(
                'Your Review',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
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
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < (_reviewData!['rating'] as int)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 22,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${_reviewData!['rating']}/5',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if ((_reviewData!['comment'] as String?)?.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 8),
                      Text(
                        _reviewData!['comment'],
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Not reviewed — show button
              ElevatedButton.icon(
                onPressed: _openReviewScreen,
                icon: const Icon(Icons.star_outline),
                label: const Text('Rate & Review'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
          // Cancel button
          if (status == 'PENDING')
            OutlinedButton(
              onPressed: _isCancelling ? null : _cancelBooking,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : const Text(
                      'Cancel Booking',
                      style: TextStyle(color: Colors.red),
                    ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textGrey),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
