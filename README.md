# Souk

Souk is a Flutter marketplace app for iOS and Android where independent shops can create mobile storefronts and customers can discover products, add them to one basket, and check out directly.

## Built so far

- Shopper home with search, category filters, quick actions, featured products, favorites, and add-to-basket actions.
- Product detail sheet with stock, rating, shop delivery info, favorite, and add-to-basket controls.
- Store discovery screen with shop stories, delivery/minimum order info, ratings, and store-specific products.
- Orders and favorites screen for purchase tracking and saved products.
- Basket with quantity controls, checkout details, delivery/pickup choice, payment choice, notes, and order placement.
- Seller hub with store draft creation, product inventory creation, starter dashboard metrics, and incoming order cards.

## Run

```bash
flutter pub get
flutter run
```

If `flutter` hangs on this machine, fix the local Flutter SDK first. The app code itself lives in `lib/main.dart` and does not depend on remote packages beyond the default Flutter SDK setup.
