import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'checkout_result.dart';

/// Razorpay Checkout through the native plugin. Android and iOS only —
/// `razorpay_flutter` declares no web platform, so on the web the conditional
/// import in `checkout.dart` picks the browser implementation instead.
///
/// The plugin reports through callbacks rather than a Future, so this bridges
/// the two with a Completer.
class Checkout {
  Checkout() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  final _razorpay = Razorpay();
  Completer<CheckoutOutcome>? _completer;

  Future<CheckoutOutcome> open(Map<String, dynamic> options) {
    _completer = Completer<CheckoutOutcome>();
    try {
      _razorpay.open(options);
    } catch (_) {
      _finish(
        const CheckoutOutcome(
          CheckoutStatus.failed,
          message: 'Could not open the payment screen.',
        ),
      );
    }
    return _completer!.future;
  }

  /// Frees the plugin's native listeners, and releases anyone still awaiting
  /// a checkout that was open when the screen went away.
  void dispose() {
    _razorpay.clear();
    _finish(const CheckoutOutcome(CheckoutStatus.cancelled));
  }

  void _onSuccess(PaymentSuccessResponse r) => _finish(
    CheckoutOutcome(
      CheckoutStatus.success,
      paymentId: r.paymentId,
      orderId: r.orderId,
      signature: r.signature,
    ),
  );

  void _onError(PaymentFailureResponse r) => _finish(
    CheckoutOutcome(
      // Code 2 is the customer dismissing the sheet, not a decline.
      r.code == Razorpay.PAYMENT_CANCELLED
          ? CheckoutStatus.cancelled
          : CheckoutStatus.failed,
      message: r.message,
    ),
  );

  void _onExternalWallet(ExternalWalletResponse r) => _finish(
    CheckoutOutcome(CheckoutStatus.externalWallet, walletName: r.walletName),
  );

  void _finish(CheckoutOutcome outcome) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(outcome);
    }
  }
}
