import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // The first screen is chosen in main() and passed in, so the test picks
    // its own rather than pulling the real one in with all its API calls.
    await tester.pumpWidget(const CustomerApp(home: SizedBox.shrink()));
    expect(find.byType(CustomerApp), findsOneWidget);
  });
}
