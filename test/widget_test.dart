import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souk_app/main.dart';

void main() {
  testWidgets('Auth screen refuses local fake login without API URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SoukApp());

    expect(find.text('Welcome to Souk'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Chris');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'chris@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Backend is not configured'), findsOneWidget);
    expect(find.text('Featured today'), findsNothing);
  });

  testWidgets('Store dashboard exposes Shopify sync and inventory controls', (
    WidgetTester tester,
  ) async {
    const session = AppSession(
      name: 'Maya',
      email: 'maya@store.com',
      role: AccountRole.seller,
      store: ShopDraft(
        id: 'test-shop-id',
        name: 'Mint Market',
        category: 'Gifts',
        city: 'Beirut',
        hasDelivery: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SellerAppShell(
          session: session,
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('Mint Market'), findsOneWidget);
    expect(find.text('Gifts - Beirut'), findsOneWidget);
    expect(find.text('Sync Shopify products'), findsOneWidget);
    expect(find.text('Shopify store URL'), findsOneWidget);

    await tester.tap(find.text('Connect Shopify'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your Shopify store URL first'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Product name'), 'Gift Candle');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '11');
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();

    expect(find.text('Gift Candle'), findsOneWidget);
    expect(find.text(r'$11.00'), findsOneWidget);
  });
}
