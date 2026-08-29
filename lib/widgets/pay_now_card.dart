import 'package:flutter/material.dart';

import '../services/payment_service.dart';
import '../theme.dart';

/// The "pay for this booking" panel, with the whole checkout behind it.
///
/// Owns its own [PaymentService] so the plugin's native listeners are torn
/// down with the widget. Callers just hand it a booking and get told when the
/// server has confirmed the money is held.
class PayNowCard extends StatefulWidget {
  final int bookingId;
  final String amount;
  final String description;
  final String contactPhone;

  /// Fired once the server confirms payment, so the parent can refresh.
  final VoidCallback? onPaid;

  /// Opens Checkout as soon as the card appears, for the straight-from-booking
  /// path where the customer has already said they want to pay now.
  final bool autoStart;

  const PayNowCard({
    super.key,
    required this.bookingId,
    required this.amount,
    this.description = '',
    this.contactPhone = '',
    this.onPaid,
    this.autoStart = false,
  });

  @override
  State<PayNowCard> createState() => _PayNowCardState();
}

class _PayNowCardState extends State<PayNowCard> {
  final _payments = PaymentService();
  bool _isPaying = false;

  /// Set when a charge may have gone through but we could not confirm it.
  /// While it is showing, the pay button stays hidden -- offering "try again"
  /// there is how a customer ends up paying twice.
  String? _pendingMessage;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      // After the first frame, so Checkout does not open over a half-built
      // screen and the SnackBar afterwards has a Scaffold to attach to.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pay();
      });
    }
  }

  @override
  void dispose() {
    _payments.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _isPaying = true);

    final result = await _payments.payForBooking(
      bookingId: widget.bookingId,
      description: widget.description,
      contactPhone: widget.contactPhone,
    );

    if (!mounted) return;
    setState(() {
      _isPaying = false;
      _pendingMessage = result.needsConfirmation ? result.message : null;
    });

    if (result.isSuccess) {
      widget.onPaid?.call();
    }

    if (!result.needsConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.isSuccess ? Colors.green.shade700 : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingMessage != null) {
      return _Panel(
        background: const Color(0xFFFFF8E1),
        border: const Color(0xFFFFE082),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule, color: Color(0xFFF57C00), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _pendingMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _Panel(
      background: AppColors.primary.withValues(alpha: 0.06),
      border: AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pay securely',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '₹${widget.amount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Your payment is held by Make My House and released to the '
            'professional only after the job is marked complete.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPaying ? null : _pay,
              icon: _isPaying
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payment, size: 18),
              label: Text(_isPaying ? 'Opening…' : 'Pay ₹${widget.amount}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color background;
  final Color border;

  const _Panel({
    required this.child,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
