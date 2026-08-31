import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'checkout_result.dart';

/// Razorpay Checkout in a browser, through the standard `checkout.js` SDK.
///
/// `razorpay_flutter` is an Android/iOS plugin — its `open()` is a bare
/// MethodChannel, so on the web it throws MissingPluginException. The browser
/// SDK is a different API shape (one options object carrying callbacks, rather
/// than listeners registered up front), so this maps it onto the same
/// [CheckoutOutcome] the native path produces.
///
/// The script is loaded by a tag in `web/index.html`.
class Checkout {
  Completer<CheckoutOutcome>? _completer;

  Future<CheckoutOutcome> open(Map<String, dynamic> options) {
    _completer = Completer<CheckoutOutcome>();

    if (!globalContext.has('Razorpay')) {
      _finish(
        const CheckoutOutcome(
          CheckoutStatus.failed,
          message:
              'The payment library did not load. Check your connection and '
              'try again.',
        ),
      );
      return _completer!.future;
    }

    try {
      final opts = _toJsObject(options);

      // Success. Nothing is confirmed by this — PaymentService still asks our
      // own server to verify the signature before calling it paid.
      opts['handler'] = ((JSObject response) {
        _finish(
          CheckoutOutcome(
            CheckoutStatus.success,
            paymentId: _readString(response, 'razorpay_payment_id'),
            orderId: _readString(response, 'razorpay_order_id'),
            signature: _readString(response, 'razorpay_signature'),
          ),
        );
      }).toJS;

      // Closing the modal is a cancellation, not a failure.
      final modal = JSObject();
      modal['ondismiss'] = (() {
        _finish(const CheckoutOutcome(CheckoutStatus.cancelled));
      }).toJS;
      opts['modal'] = modal;

      final razorpay = _RazorpayJs(opts);
      razorpay.on(
        'payment.failed',
        ((JSObject response) {
          final error = response['error'];
          _finish(
            CheckoutOutcome(
              CheckoutStatus.failed,
              message: error.isA<JSObject>()
                  ? _readString(error as JSObject, 'description')
                  : null,
            ),
          );
        }).toJS,
      );
      razorpay.open();
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

  /// Releases anyone awaiting a checkout that was still open when the screen
  /// went away. There are no native listeners to free in a browser.
  void dispose() {
    _finish(const CheckoutOutcome(CheckoutStatus.cancelled));
  }

  void _finish(CheckoutOutcome outcome) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(outcome);
    }
  }

  static String? _readString(JSObject object, String property) {
    final value = object[property];
    if (value == null) return null;
    return value.dartify()?.toString();
  }

  static JSObject _toJsObject(Map<String, dynamic> map) {
    final object = JSObject();
    map.forEach((key, value) => object[key] = _toJsValue(value));
    return object;
  }

  static JSAny? _toJsValue(Object? value) {
    return switch (value) {
      null => null,
      final String v => v.toJS,
      final int v => v.toJS,
      final double v => v.toJS,
      final bool v => v.toJS,
      final Map<String, dynamic> v => _toJsObject(v),
      final Map v => _toJsObject(v.map((k, dynamic e) => MapEntry('$k', e))),
      // Anything else came from a JSON response; the SDK reads these as
      // strings anyway.
      _ => value.toString().toJS,
    };
  }
}

@JS('Razorpay')
extension type _RazorpayJs._(JSObject _) implements JSObject {
  external factory _RazorpayJs(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}
