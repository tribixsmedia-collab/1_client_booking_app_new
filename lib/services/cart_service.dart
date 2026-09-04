import 'package:flutter/foundation.dart';

/// A quantity the way a line shows it: no trailing ".0" on a whole number,
/// two places when there really is a fraction. Quantities are doubles now
/// because a measured line carries 1000 sq ft or 2.5 kg.
String formatQuantity(double quantity) => quantity == quantity.roundToDouble()
    ? quantity.toStringAsFixed(0)
    : quantity.toStringAsFixed(2);


class CartItem {
  final int serviceId;
  final String name;

  /// A rate, not a total. What it is a rate *of* is [pricingType] — a flat
  /// price, or one square foot, or one hour.
  final double price;
  final int categoryId;
  final int? subcategoryId;
  final String categoryName;

  /// How many, or how much. A count for the things that are counted, a
  /// measurement for the things that are measured — 1000 sq ft, 2.5 kg —
  /// which is why it is not an int.
  double quantity;

  /// Enough of the service's pricing to render and total this line without
  /// asking the server again.
  final String pricingType;

  /// "sq ft", "hour", or empty for a flat price.
  final String unitLabel;

  /// Whether [quantity] is a measurement the customer typed rather than a
  /// count they stepped up and down.
  final bool needsQuantity;

  int? formId;
  List<Map<String, dynamic>>? formData;

  CartItem({
    required this.serviceId,
    required this.name,
    required this.price,
    required this.categoryId,
    this.subcategoryId,
    required this.categoryName,
    this.quantity = 1,
    this.pricingType = 'FIXED',
    this.unitLabel = '',
    this.needsQuantity = false,
    this.formId,
    this.formData,
  });

  double get total => price * quantity;

  /// The quantity as a line shows it: "1000 sq ft", "2.5 kg", "3".
  /// Trailing zeros are dropped so a whole number never reads as "3.0".
  String get quantityLabel {
    final amount = formatQuantity(quantity);
    return unitLabel.isEmpty ? amount : '$amount $unitLabel';
  }

  String get formSummary {
    if (formData == null || formData!.isEmpty) return '';
    return formData!
        .where((r) => (r['answer'] as String?)?.isNotEmpty ?? false)
        .map((r) => '${r['title']}: ${r['answer']}')
        .join(' • ');
  }

  Map<String, dynamic> toJson() => {
    'id': serviceId,
    'name': name,
    'price': price,
    // Sent as a number, not an int: the server multiplies it as a Decimal, so
    // 1000 sq ft and 2.5 kg both survive the round trip.
    'qty': quantity,
    'pricing_type': pricingType,
    if (unitLabel.isNotEmpty) 'unit': unitLabel,
    if (formId != null) 'form_id': formId,
    if (formData != null) 'form_data': formData,
  };
}

class CartService extends ChangeNotifier {
  double _autoDiscount = 0;
  double _couponDiscount = 0;
  String _autoDiscountName = '';
  String _couponCode = '';

  double get autoDiscount => _autoDiscount;
  double get couponDiscount => _couponDiscount;
  double get totalDiscount => _autoDiscount + _couponDiscount;
  double get finalAmount =>
      (totalAmount - totalDiscount).clamp(0, double.infinity);
  String get autoDiscountName => _autoDiscountName;
  String get couponCode => _couponCode;

  void setAutoDiscount(double amount, String name) {
    _autoDiscount = amount;
    _autoDiscountName = name;
    notifyListeners();
  }

  void setCouponDiscount(double amount, String code) {
    _couponDiscount = amount;
    _couponCode = code;
    notifyListeners();
  }

  void clearCoupon() {
    _couponDiscount = 0;
    _couponCode = '';
    notifyListeners();
  }

  static final CartService _instance = CartService._();
  factory CartService() => _instance;
  CartService._();

  final List<CartItem> _items = [];

  int? _currentCategoryId;
  int? _currentSubcategoryId;
  String _currentCategoryName = '';

  // The pro vendor the customer asked for, carried from a service page or a
  // vendor profile through to the booking. Only a request -- the admin still
  // decides who actually gets assigned.
  int? _preferredVendorId;
  String _preferredVendorName = '';
  List<int> _preferredVendorCategoryIds = const [];

  int? get preferredVendorId => _preferredVendorId;
  String get preferredVendorName => _preferredVendorName;

  void setPreferredVendor(
    int vendorId,
    String name, {
    List<int> categoryIds = const [],
  }) {
    _preferredVendorId = vendorId;
    _preferredVendorName = name;
    _preferredVendorCategoryIds = categoryIds;
    notifyListeners();
  }

  void clearPreferredVendor() {
    _preferredVendorId = null;
    _preferredVendorName = '';
    _preferredVendorCategoryIds = const [];
    notifyListeners();
  }

  /// Whether the requested pro belongs on the booking for [categoryId].
  ///
  /// A cart can span categories and each one becomes its own booking, so the
  /// pro only rides along with the categories they actually cover. An empty
  /// list means "not known", in which case the request goes on every booking.
  bool preferredVendorAppliesTo(int categoryId) =>
      _preferredVendorId != null &&
      (_preferredVendorCategoryIds.isEmpty ||
          _preferredVendorCategoryIds.contains(categoryId));

  List<CartItem> get items => List.unmodifiable(_items);

  /// How many things are in the cart, for the "N items | ₹X" bar.
  ///
  /// A measured line counts as one thing however much of it was ordered —
  /// 1000 sq ft of tiling is one item on the bill, not a thousand. Counted
  /// lines still add up the way they always did.
  int get totalItems => _items.fold(
    0,
    (sum, item) => sum + (item.needsQuantity ? 1 : item.quantity.round()),
  );

  double get totalAmount => _items.fold(0, (sum, item) => sum + item.total);
  bool get isEmpty => _items.isEmpty;

  void setCategoryInfo({
    required int categoryId,
    int? subcategoryId,
    required String categoryName,
  }) {
    _currentCategoryId = categoryId;
    _currentSubcategoryId = subcategoryId;
    _currentCategoryName = categoryName;
    notifyListeners();
  }

  void addItem({
    required int serviceId,
    required String name,
    required double price,
    double quantity = 1,
    String pricingType = 'FIXED',
    String unitLabel = '',
    bool needsQuantity = false,
    int? formId,
    List<Map<String, dynamic>>? formData,
  }) {
    // If service has form data, always add as new item (each config is unique)
    if (formData != null && formData.isNotEmpty) {
      _items.add(
        CartItem(
          serviceId: serviceId,
          name: name,
          price: price,
          categoryId: _currentCategoryId!,
          subcategoryId: _currentSubcategoryId,
          categoryName: _currentCategoryName,
          quantity: quantity,
          pricingType: pricingType,
          unitLabel: unitLabel,
          needsQuantity: needsQuantity,
          formId: formId,
          formData: formData,
        ),
      );
    } else {
      // No form — increment quantity if exists
      final existing = _items
          .where((i) => i.serviceId == serviceId && i.formData == null)
          .toList();
      if (existing.isNotEmpty) {
        // A measured line is replaced, not stepped up: adding 1000 sq ft
        // twice means the customer corrected the figure, not that they want
        // 2000. Counted lines still increment.
        if (needsQuantity) {
          existing.first.quantity = quantity;
        } else {
          existing.first.quantity += quantity;
        }
      } else {
        _items.add(
          CartItem(
            serviceId: serviceId,
            name: name,
            price: price,
            categoryId: _currentCategoryId!,
            subcategoryId: _currentSubcategoryId,
            categoryName: _currentCategoryName,
            quantity: quantity,
            pricingType: pricingType,
            unitLabel: unitLabel,
            needsQuantity: needsQuantity,
          ),
        );
      }
    }
    notifyListeners();
  }

  /// Steps a counted line down by one, or drops a measured line outright —
  /// there is no sense in taking one square foot off a thousand.
  void removeItem(int serviceId, {int? itemIndex}) {
    if (itemIndex != null && itemIndex < _items.length) {
      final item = _items[itemIndex];
      if (!item.needsQuantity && item.quantity > 1) {
        item.quantity--;
      } else {
        _items.removeAt(itemIndex);
      }
    } else {
      final existing = _items
          .where((i) => i.serviceId == serviceId && i.formData == null)
          .toList();
      if (existing.isNotEmpty) {
        if (!existing.first.needsQuantity && existing.first.quantity > 1) {
          existing.first.quantity--;
        } else {
          _items.removeWhere(
            (i) => i.serviceId == serviceId && i.formData == null,
          );
        }
      }
    }
    notifyListeners();
  }

  void updateItemForm(int itemIndex, List<Map<String, dynamic>> newFormData) {
    if (itemIndex < _items.length) {
      _items[itemIndex].formData = newFormData;
      notifyListeners();
    }
  }

  void removeAt(int index) {
    if (index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  double getQuantity(int serviceId) {
    return _items
        .where((i) => i.serviceId == serviceId)
        .fold(0.0, (sum, i) => sum + i.quantity);
  }

  /// Sets a measured line to exactly [quantity], dropping it at zero.
  /// What the number box on a per-sq-ft service writes to.
  void setQuantity(int serviceId, double quantity) {
    final existing = _items
        .where((i) => i.serviceId == serviceId && i.formData == null)
        .toList();
    if (existing.isEmpty) return;

    if (quantity <= 0) {
      _items.remove(existing.first);
    } else {
      existing.first.quantity = quantity;
    }
    notifyListeners();
  }

  Map<String, List<CartItem>> get groupedByCategory {
    final map = <String, List<CartItem>>{};
    for (final item in _items) {
      final key = item.categoryName;
      map.putIfAbsent(key, () => []);
      map[key]!.add(item);
    }
    return map;
  }

  List<Map<String, dynamic>> get distinctCategories {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final item in _items) {
      if (seen.add(item.categoryId)) {
        result.add({
          'categoryId': item.categoryId,
          'subcategoryId': item.subcategoryId,
          'categoryName': item.categoryName,
          'items': _items
              .where((i) => i.categoryId == item.categoryId)
              .toList(),
        });
      }
    }
    return result;
  }

  void clear() {
    _items.clear();
    _currentCategoryId = null;
    _currentSubcategoryId = null;
    _currentCategoryName = '';
    _autoDiscount = 0;
    _couponDiscount = 0;
    _autoDiscountName = '';
    _couponCode = '';
    _preferredVendorId = null;
    _preferredVendorName = '';
    _preferredVendorCategoryIds = const [];
    notifyListeners();
  }
}
