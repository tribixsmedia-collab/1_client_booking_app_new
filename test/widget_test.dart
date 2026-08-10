import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CustomerApp());
    expect(find.byType(CustomerApp), findsOneWidget);
  });
}
