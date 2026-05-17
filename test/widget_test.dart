import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souk_app/main.dart';

void main() {
  testWidgets('Customer signs up, shops, and places an order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SoukApp());

    expect(find.text('Welcome to Souk'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Chris');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'chris@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Featured today'), findsOneWidget);
    expect(find.text('Zaatar Breakfast Box'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pump();

    await tester.tap(find.text('Basket'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout details'), findsOneWidget);
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Placed'), findsOneWidget);
  });

  testWidgets('Store owner signs up with store details and adds inventory', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SoukApp());

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Maya');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'maya@store.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Store name'), 'Mint Market');
    await tester.enterText(find.widgetWithText(TextFormField, 'Store category'), 'Gifts');
    await tester.enterText(find.widgetWithText(TextFormField, 'City or area'), 'Beirut');
    await tester.tap(find.text('Create account'));
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
