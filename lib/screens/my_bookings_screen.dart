import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'booking_detail_screen.dart';

/// How one booking status is presented on the card.
class _StatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusStyle(this.label, this.color, this.icon);
}

/// Shows the logged-in customer's own bookings with their current status.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<dynamic>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = ApiService.getMyBookings();
  }

  Future<void> _refresh() async {
    setState(() {
      _bookingsFuture = ApiService.getMyBookings();
    });
  }

  /// Labels stay short here — the pill sits beside the category name and a
  /// full sentence overflows on narrow phones. The long form is on the
  /// detail screen's timeline.
  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'PENDING':
        return _StatusStyle('Pending', Colors.orange.shade800, Icons.schedule);
      case 'ASSIGNED':
        return _StatusStyle(
          'Assigned',
          Colors.blue.shade700,
          Icons.person_pin_circle_outlined,
        );
      case 'IN_PROGRESS':
        return const _StatusStyle(
          'In progress',
          AppColors.primary,
          Icons.handyman_outlined,
        );
      case 'COMPLETED':
        return _StatusStyle(
          'Completed',
          Colors.green.shade700,
          Icons.check_circle_outline,
        );
      case 'CANCELLED':
        return _StatusStyle(
          'Cancelled',
          Colors.red.shade600,
          Icons.cancel_outlined,
        );
      default:
        return _StatusStyle(status, AppColors.textGrey, Icons.help_outline);
    }
  }

  /// '2026-08-12' + '10:30:00' -> 'Wed, 12 Aug · 10:30 AM'.
  /// Falls back to the raw values if the backend sends something unexpected.
  String _schedule(dynamic date, dynamic time) {
    final rawDate = '${date ?? ''}'.trim();
    final rawTime = '${time ?? ''}'.trim();
    final parsed = DateTime.tryParse('$rawDate $rawTime');
    if (parsed == null) {
      return [rawDate, rawTime].where((s) => s.isNotEmpty).join(' ');
    }
    return DateFormat("EEE, d MMM · h:mm a").format(parsed);
  }

  String _amount(dynamic amount) {
    final value = double.tryParse('${amount ?? ''}');
    if (value == null) return '₹${amount ?? 0}';
    return '₹${NumberFormat.decimalPattern('en_IN').format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _centered(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load your bookings',
                message: '${snapshot.error}'.replaceFirst('Exception: ', ''),
                action: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              );
            }

            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return _centered(
                icon: Icons.receipt_long_outlined,
                title: 'No bookings yet',
                message:
                    'Your booked services will appear here once you place an order.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: bookings.length,
              itemBuilder: (context, index) =>
                  _bookingCard(Map<String, dynamic>.from(bookings[index])),
            );
          },
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final style = _statusStyle('${b['status']}');
    final vendorName = b['vendor_name'];
    final preferredVendorName = b['preferred_vendor_name'];
    final notes = '${b['notes'] ?? ''}'.trim();
    final isCancelled = b['status'] == 'CANCELLED';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
          );
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${b['category_name'] ?? 'Service'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Booking #${b['id']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _statusPill(style),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEFEFF4)),
              const SizedBox(height: 14),

              _detailRow(
                Icons.event_outlined,
                _schedule(b['preferred_date'], b['preferred_time']),
              ),
              if (vendorName != null)
                _detailRow(Icons.badge_outlined, '$vendorName'),
              // Only worth a line while the request is still open — once the
              // pro is on the job the vendor row above already says so.
              if (preferredVendorName != null &&
                  preferredVendorName != vendorName)
                _detailRow(
                  Icons.verified_outlined,
                  'Requested pro: $preferredVendorName',
                ),
              if (notes.isNotEmpty)
                _detailRow(Icons.notes_outlined, notes, maxLines: 2),

              const SizedBox(height: 14),

              Row(
                children: [
                  Text(
                    _amount(b['amount']),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isCancelled
                          ? AppColors.textGrey
                          : AppColors.textDark,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const Spacer(),
                  _paymentChip('${b['payment_status']}'),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textGrey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(_StatusStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentChip(String paymentStatus) {
    final isPaid = paymentStatus == 'PAID';
    final color = isPaid ? Colors.green.shade700 : Colors.orange.shade800;
    final label = isPaid
        ? 'Paid'
        : paymentStatus == 'UNPAID'
        ? 'Unpaid'
        : 'Payment pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty and error states. Kept scrollable so pull-to-refresh still works
  /// when there is nothing in the list.
  Widget _centered({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEDE7F6),
                    ),
                    child: Icon(icon, size: 34, color: AppColors.primary),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.textGrey,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
