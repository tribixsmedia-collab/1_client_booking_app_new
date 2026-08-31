/// How one Checkout attempt ended, expressed in terms both the native plugin
/// and the browser SDK can produce.
///
/// Deliberately says nothing about whether money moved — only the server can
/// answer that, and [PaymentService] asks it before reporting success.
enum CheckoutStatus {
  /// Checkout handed back a payment id and signature. Still unverified.
  success,

  /// The customer closed the sheet.
  cancelled,

  /// Declined, or Checkout could not be opened.
  failed,

  /// The customer left for a wallet app. Native only — the browser SDK keeps
  /// wallet flows inside its own window.
  externalWallet,
}

class CheckoutOutcome {
  const CheckoutOutcome(
    this.status, {
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
    this.walletName,
  });

  final CheckoutStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
  final String? walletName;
}
