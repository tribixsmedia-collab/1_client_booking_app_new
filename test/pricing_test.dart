// The customer app's half of the pricing flow.
//
// The server is checked end to end by services/tests_pricing_flow.py; these
// cover what happens before the cart is ever posted — that a service payload
// is read correctly, and that the cart totals the same figures the customer
// was shown.

import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/models/service_pricing.dart';
import 'package:customer_app/services/cart_service.dart';

/// A service payload shaped like the one the API returns.
Map<String, dynamic> payload({
  required String type,
  required String label,
  String unit = '',
  String measure = '',
  bool needsQuantity = false,
  bool decimals = false,
  bool quoteOnly = false,
}) => {
  'pricing_type': type,
  'price_label': label,
  'unit_label': unit,
  'measure_label': measure,
  'needs_quantity': needsQuantity,
  'allows_decimal_quantity': decimals,
  'is_quote_only': quoteOnly,
};

void main() {
  group('ServicePricing', () {
    test('reads a per-unit service off its payload', () {
      final pricing = ServicePricing.fromJson(
        payload(
          type: 'PER_SQ_FT',
          label: '₹15 / sq ft',
          unit: 'sq ft',
          measure: 'Area (sq ft)',
          needsQuantity: true,
          decimals: true,
        ),
        15,
      );

      expect(pricing.type, 'PER_SQ_FT');
      expect(pricing.priceLabel, '₹15 / sq ft');
      expect(pricing.unitLabel, 'sq ft');
      expect(pricing.measureLabel, 'Area (sq ft)');
      expect(pricing.needsQuantity, isTrue);
      expect(pricing.allowsDecimal, isTrue);
      expect(pricing.isQuoteOnly, isFalse);
    });

    test('a quote service carries no orderable price', () {
      final pricing = ServicePricing.fromJson(
        payload(
          type: 'CUSTOM_QUOTE',
          label: 'Price on request',
          quoteOnly: true,
        ),
        0,
      );

      expect(pricing.isQuoteOnly, isTrue);
      expect(pricing.needsQuantity, isFalse);
      expect(pricing.priceLabel, 'Price on request');
    });

    test('a payload from before pricing types still shows its price', () {
      // Nothing but a price — the old shape. It must not render blank.
      final pricing = ServicePricing.fromJson(<String, dynamic>{}, 800);

      expect(pricing.type, 'FIXED');
      expect(pricing.priceLabel, '₹800');
      expect(pricing.needsQuantity, isFalse);
    });
  });

  group('cart totals', () {
    setUp(CartService().clear);

    test('a measured line is charged rate x amount', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'Tiling')
        ..addItem(
          serviceId: 1,
          name: 'Floor tiling',
          price: 15,
          quantity: 1000,
          pricingType: 'PER_SQ_FT',
          unitLabel: 'sq ft',
          needsQuantity: true,
        );

      expect(cart.totalAmount, 15000);
      expect(cart.items.first.quantityLabel, '1000 sq ft');
    });

    test('a fractional amount is not rounded away', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'Laundry')
        ..addItem(
          serviceId: 1,
          name: 'Laundry',
          price: 50,
          quantity: 2.5,
          pricingType: 'PER_KG',
          unitLabel: 'kg',
          needsQuantity: true,
        );

      expect(cart.totalAmount, 125);
      expect(cart.items.first.quantityLabel, '2.50 kg');
    });

    test('the mixed cart from the spec adds up', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'Home')
        ..addItem(
          serviceId: 1,
          name: 'Floor tiling',
          price: 15,
          quantity: 1000,
          pricingType: 'PER_SQ_FT',
          unitLabel: 'sq ft',
          needsQuantity: true,
        )
        ..addItem(serviceId: 2, name: 'AC service', price: 800);

      expect(cart.totalAmount, 15800);
      // 1000 sq ft is one thing on the bill, not a thousand.
      expect(cart.totalItems, 2);
    });

    test('adding a measured line again replaces the amount', () {
      // Re-entering 1200 means the customer corrected the figure, not that
      // they now want 2200 sq ft.
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'Tiling');
      for (final amount in [1000.0, 1200.0]) {
        cart.addItem(
          serviceId: 1,
          name: 'Floor tiling',
          price: 15,
          quantity: amount,
          pricingType: 'PER_SQ_FT',
          unitLabel: 'sq ft',
          needsQuantity: true,
        );
      }

      expect(cart.items.single.quantity, 1200);
      expect(cart.totalAmount, 18000);
    });

    test('a counted line still steps up one at a time', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'AC')
        ..addItem(serviceId: 1, name: 'AC service', price: 800)
        ..addItem(serviceId: 1, name: 'AC service', price: 800);

      expect(cart.items.single.quantity, 2);
      expect(cart.totalAmount, 1600);
      expect(cart.totalItems, 2);
    });

    test('removing a measured line drops it whole', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'Tiling')
        ..addItem(
          serviceId: 1,
          name: 'Floor tiling',
          price: 15,
          quantity: 1000,
          pricingType: 'PER_SQ_FT',
          unitLabel: 'sq ft',
          needsQuantity: true,
        )
        ..removeItem(1);

      // There is no sense in taking one square foot off a thousand.
      expect(cart.isEmpty, isTrue);
    });

    test('a counted line steps down one at a time', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'AC')
        ..addItem(serviceId: 1, name: 'AC service', price: 800, quantity: 3)
        ..removeItem(1);

      expect(cart.items.single.quantity, 2);
    });

    test('a line is posted with the quantity the customer saw', () {
      final cart = CartService()
        ..setCategoryInfo(categoryId: 1, categoryName: 'Tiling')
        ..addItem(
          serviceId: 1,
          name: 'Floor tiling',
          price: 15,
          quantity: 1000,
          pricingType: 'PER_SQ_FT',
          unitLabel: 'sq ft',
          needsQuantity: true,
        );

      final json = cart.items.single.toJson();
      expect(json['qty'], 1000.0);
      expect(json['price'], 15);
      expect(json['pricing_type'], 'PER_SQ_FT');
      expect(json['unit'], 'sq ft');
    });
  });

  group('a quote service read off a list payload', () {
    // The bug this pins: a category holding exactly one service opened the
    // detail screen without its pricing, so a quote showed a price instead of
    // "Price on request". Both routes now build the screen the same way, and
    // both read the pricing out of the same payload shape.
    final listPayload = {
      'id': 7,
      'name': 'House Painting',
      'price': '0.00',
      'pricing_type': 'CUSTOM_QUOTE',
      'price_label': 'Price on request',
      'unit_label': '',
      'measure_label': '',
      'needs_quantity': false,
      'allows_decimal_quantity': false,
      'is_quote_only': true,
      'tender_project_type': 'INTERIOR',
    };

    test('says price on request, not a figure', () {
      final pricing = ServicePricing.fromJson(
        listPayload,
        double.tryParse('${listPayload['price']}') ?? 0,
      );

      expect(pricing.priceLabel, 'Price on request');
      expect(pricing.priceLabel, isNot(contains('0')));
      expect(pricing.isQuoteOnly, isTrue);
    });

    test('carries the project type the tender form opens with', () {
      final pricing = ServicePricing.fromJson(listPayload, 0);
      expect(pricing.tenderProjectType, 'INTERIOR');
    });

    test('a payload missing the pricing keys falls back to the price', () {
      // What the old bug looked like: no pricing passed, so a flat label.
      final pricing = ServicePricing.fixed(0);
      expect(pricing.priceLabel, '₹0');
      expect(pricing.isQuoteOnly, isFalse);
    });
  });

  group('quantity formatting', () {
    test('a whole number carries no decimal point', () {
      expect(formatQuantity(3), '3');
      expect(formatQuantity(1000), '1000');
    });

    test('a real fraction keeps its places', () {
      expect(formatQuantity(2.5), '2.50');
    });
  });
}
