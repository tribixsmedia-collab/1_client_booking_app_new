/// Razorpay Checkout, whichever way this platform can open it.
///
/// Android and iOS use the `razorpay_flutter` plugin; the web uses Razorpay's
/// `checkout.js` SDK, because the plugin declares no web platform and its
/// MethodChannel throws MissingPluginException in a browser.
///
/// Both expose the same `Checkout` class — construct one, `open(options)`,
/// await a [CheckoutOutcome], and `dispose()`.
library;

export 'checkout_mobile.dart' if (dart.library.js_interop) 'checkout_web.dart';
export 'checkout_result.dart';
