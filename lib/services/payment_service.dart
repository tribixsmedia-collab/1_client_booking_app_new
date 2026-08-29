import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'api_service.dart';

/// How a checkout attempt ended.
enum PaymentOutcome {
  /// The server has confirmed the money is held. Only this means paid.
  success,

  /// The customer closed Checkout or the payment was declined.
  failed,

  /// Razorpay took the money but we could not confirm it before the app lost
  /// the network. Not a failure -- the webhook settles it server-side, so the
  /// booking will show as paid shortly. Never retry a charge on this.
  pendingConfirmation,
}

class PaymentResult {
  final PaymentOutcome outcome;
  final String message;
  final String? paymentId;

  const PaymentResult(this.outcome, this.message, {this.paymentId});

  bool get isSuccess => outcome == PaymentOutcome.success;
  bool get needsConfirmation => outcome == PaymentOutcome.pendingConfirmation;
}

/// Runs one Razorpay checkout for one booking.
///
/// The plugin reports its result through callbacks rather than a Future, so
/// this bridges the two with a Completer and hands back a single awaitable
/// result. A fresh instance is used per attempt and disposed straight after,
/// because a reused one keeps its old handlers attached.
///
/// Nothing here decides what is owed. The amount, the order and the final
/// verdict all come from the server; this only carries values between
/// Razorpay and our API.
class PaymentService {
  final _razorpay = Razorpay();
  Completer<PaymentResult>? _completer;

  int? _bookingId;
  String? _orderId;

  PaymentService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  /// Frees the plugin's native listeners. Call from the caller's `dispose`.
  void dispose() {
    _razorpay.clear();
    // A checkout still open when the screen goes away would otherwise leave
    // whoever is awaiting this hanging forever.
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(
        const PaymentResult(PaymentOutcome.failed, 'Payment was cancelled.'),
      );
    }
  }

  /// Opens Checkout for [bookingId] and resolves once the outcome is known.
  ///
  /// [contactPhone] and [email] only prefill the form; Razorpay works without
  /// them and they are not used for anything else.
  Future<PaymentResult> payForBooking({
    required int bookingId,
    String description = '',
    String contactPhone = '',
    String email = '',
  }) async {
    if (_completer != null && !_completer!.isCompleted) {
      return const PaymentResult(
        PaymentOutcome.failed,
        'A payment is already in progress.',
      );
    }

    Map<String, dynamic> order;
    try {
      order = await ApiService.createPaymentOrder(bookingId);
    } catch (e) {
      return PaymentResult(
        PaymentOutcome.failed,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }

    _bookingId = bookingId;
    _orderId = '${order['order_id']}';
    _completer = Completer<PaymentResult>();

    try {
      _razorpay.open({
        // Every value below comes from the server's order response. The app
        // never composes an amount of its own.
        'key': order['key_id'],
        'order_id': order['order_id'],
        'amount': order['amount'], // paise
        'currency': order['currency'] ?? 'INR',
        'name': 'Make My House',
        'description': description.isEmpty ? 'Booking #$bookingId' : description,
        'prefill': {
          if (contactPhone.isNotEmpty) 'contact': contactPhone,
          if (email.isNotEmpty) 'email': email,
        },
        'retry': {'enabled': true, 'max_count': 1},
        'timeout': 300,
      });
    } catch (e) {
      _completer!.complete(
        const PaymentResult(
          PaymentOutcome.failed,
          'Could not open the payment screen.',
        ),
      );
    }

    return _completer!.future;
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    // Razorpay says it worked, but only the server can confirm the money is
    // actually held -- so this stays unpaid until our own API agrees.
    try {
      await ApiService.verifyPayment(
        orderId: response.orderId ?? _orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      _finish(
        PaymentResult(
          PaymentOutcome.success,
          'Payment successful.',
          paymentId: response.paymentId,
        ),
      );
    } catch (_) {
      // Verification did not get through. The charge may well have gone
      // through, so ask the server what it knows rather than assuming either
      // way -- Razorpay's webhook may already have settled it.
      _finish(await _reconcile(response.paymentId));
    }
  }

  /// Last word on an attempt we could not verify directly.
  Future<PaymentResult> _reconcile(String? paymentId) async {
    if (_bookingId == null) {
      return const PaymentResult(
        PaymentOutcome.pendingConfirmation,
        'We could not confirm your payment. It will update shortly.',
      );
    }
    try {
      final status = await ApiService.getBookingPaymentStatus(_bookingId!);
      if (status['is_paid'] == true) {
        return PaymentResult(
          PaymentOutcome.success,
          'Payment successful.',
          paymentId: paymentId,
        );
      }
    } catch (_) {
      // Still offline. Fall through -- the webhook is the backstop.
    }
    return PaymentResult(
      PaymentOutcome.pendingConfirmation,
      'Your payment is being confirmed. This booking will update shortly — '
      'please do not pay again.',
      paymentId: paymentId,
    );
  }

  void _onError(PaymentFailureResponse response) {
    // Code 2 is the customer dismissing the sheet, which is not an error
    // worth showing them in red.
    final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    _finish(
      PaymentResult(
        PaymentOutcome.failed,
        cancelled
            ? 'Payment cancelled.'
            : (_readableError(response.message) ?? 'Payment failed.'),
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // The customer left for a wallet app. Nothing is confirmed until the
    // server says so, so treat it the same as any unconfirmed attempt.
    _finish(
      PaymentResult(
        PaymentOutcome.pendingConfirmation,
        'Complete the payment in ${response.walletName ?? 'your wallet'}. '
        'This booking will update once it goes through.',
      ),
    );
  }

  /// Razorpay puts a JSON blob in `message` for some failures; show the
  /// human sentence inside it rather than the raw payload.
  String? _readableError(String? message) {
    if (message == null || message.isEmpty) return null;
    final match = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(message);
    return match?.group(1) ?? message;
  }

  void _finish(PaymentResult result) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(result);
    }
  }
}
