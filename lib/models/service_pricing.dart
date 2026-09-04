/// How a service's price becomes an amount.
///
/// `price` on a service is only ever a rate. What it is a rate *of* lives
/// here: a flat ₹800, ₹15 for every square foot, or nothing bookable at all
/// because a vendor has to come and look first.
///
/// Built from whatever `/api/services/...` returned, and defaulting to a flat
/// price when a screen has no pricing to hand — so a service loaded from an
/// older payload behaves exactly as it did before pricing types existed.
class ServicePricing {
  /// One of the server's PricingType values: FIXED, PER_SQ_FT, CUSTOM_QUOTE…
  final String type;

  /// The ready-made line a card shows: "₹15 / sq ft", "From ₹499",
  /// "Price on request".
  final String priceLabel;

  /// "sq ft", "hour", or empty for a flat price.
  final String unitLabel;

  /// What to put above the quantity box: "Area (sq ft)", "Hours".
  final String measureLabel;

  /// Whether the customer is asked for an amount before this can be priced.
  final bool needsQuantity;

  /// Whether half of one unit is a real amount to charge for.
  final bool allowsDecimal;

  /// No bookable price — these go to the tender flow for a quote.
  final bool isQuoteOnly;

  /// The project type the tender form should open with, for a quote service.
  /// Empty leaves the form on its own default and the customer picks.
  final String tenderProjectType;

  const ServicePricing({
    required this.type,
    required this.priceLabel,
    this.unitLabel = '',
    this.measureLabel = '',
    this.needsQuantity = false,
    this.allowsDecimal = false,
    this.isQuoteOnly = false,
    this.tenderProjectType = '',
  });

  /// A flat price, for callers with nothing better. [price] only shapes the
  /// label; everything else about FIXED is already the default.
  factory ServicePricing.fixed(double price) => ServicePricing(
    type: 'FIXED',
    priceLabel: '₹${price.toStringAsFixed(0)}',
  );

  /// Reads the pricing fields off a service payload.
  ///
  /// [price] is the fallback for the label alone: a payload from before these
  /// fields existed still renders its price, just without a unit on it.
  factory ServicePricing.fromJson(Map<String, dynamic> json, double price) {
    final label = (json['price_label'] as String?) ?? '';
    return ServicePricing(
      type: (json['pricing_type'] as String?) ?? 'FIXED',
      priceLabel: label.isNotEmpty ? label : '₹${price.toStringAsFixed(0)}',
      unitLabel: (json['unit_label'] as String?) ?? '',
      measureLabel: (json['measure_label'] as String?) ?? '',
      needsQuantity: json['needs_quantity'] == true,
      allowsDecimal: json['allows_decimal_quantity'] == true,
      isQuoteOnly: json['is_quote_only'] == true,
      tenderProjectType: (json['tender_project_type'] as String?) ?? '',
    );
  }
}
