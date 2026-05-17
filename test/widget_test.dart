import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souk_app/main.dart';

void main() {
  testWidgets('Souk app adds an item and places an order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SoukApp());

    expect(find.text('Featured today'), findsOneWidget);
    expect(find.text('Zaatar Breakfast Box'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pump();

    await tester.tap(find.text('Basket'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout details'), findsOneWidget);
    expect(find.text('Place order'), findsOneWidget);

    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsWidgets);
    expect(find.textContaining('Placed'), findsOneWidget);
  });

  testWidgets('Seller can create a store draft and product', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SoukApp());

    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Store name'), 'Mint Market');
    await tester.enterText(find.widgetWithText(TextFormField, 'Main category'), 'Gifts');
    await tester.enterText(find.widgetWithText(TextFormField, 'City or area'), 'Beirut');
    await tester.tap(find.text('Launch store draft'));
    await tester.pumpAndSettle();

    expect(find.text('Mint Market'), findsOneWidget);
    expect(find.text('Gifts - Beirut'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Product name'), 'Gift Candle');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '11');
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();

    expect(find.text('Gift Candle'), findsOneWidget);
    expect(find.text(r'$11.00'), findsOneWidget);
  });
}
