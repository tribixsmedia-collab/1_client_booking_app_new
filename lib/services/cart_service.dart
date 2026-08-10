import 'package:flutter/foundation.dart';

class CartItem {
  final int serviceId;
  final String name;
  final double price;
  final int categoryId;
  final int? subcategoryId;
  final String categoryName;
  int quantity;
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
    this.formId,
    this.formData,
  });

  double get total => price * quantity;

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
    'qty': quantity,
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

  List<CartItem> get items => List.unmodifiable(_items);
  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);
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
        existing.first.quantity++;
      } else {
        _items.add(
          CartItem(
            serviceId: serviceId,
            name: name,
            price: price,
            categoryId: _currentCategoryId!,
            subcategoryId: _currentSubcategoryId,
            categoryName: _currentCategoryName,
          ),
        );
      }
    }
    notifyListeners();
  }

  void removeItem(int serviceId, {int? itemIndex}) {
    if (itemIndex != null && itemIndex < _items.length) {
      final item = _items[itemIndex];
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _items.removeAt(itemIndex);
      }
    } else {
      final existing = _items
          .where((i) => i.serviceId == serviceId && i.formData == null)
          .toList();
      if (existing.isNotEmpty) {
        if (existing.first.quantity > 1) {
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

  int getQuantity(int serviceId) {
    return _items
        .where((i) => i.serviceId == serviceId)
        .fold(0, (sum, i) => sum + i.quantity);
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
    notifyListeners();
  }
}
