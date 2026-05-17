# Souk

Souk is a Flutter marketplace app for iOS and Android where independent shops can create mobile storefronts and customers can discover products, add them to one basket, and check out directly.

## Built so far

- Shopper home with search, category filters, quick actions, featured products, favorites, and add-to-basket actions.
- Product detail sheet with stock, rating, shop delivery info, favorite, and add-to-basket controls.
- Store discovery screen with shop stories, delivery/minimum order info, ratings, and store-specific products.
- Orders and favorites screen for purchase tracking and saved products.
- Basket with quantity controls, checkout details, delivery/pickup choice, payment choice, notes, and order placement.
- Seller hub with store draft creation, product inventory creation, starter dashboard metrics, and incoming order cards.
- Railway-ready backend in `backend/` with PostgreSQL, Prisma, shops, products, orders, users, favorites, reviews, and seed data.
- Account-first flow: customers sign up/login to shop, while store owners sign up/login through a separate store account path.
- Seller dashboard Shopify panel for OAuth login, then syncing products, collections, images, prices, descriptions, and inventory.

## Run

```bash
flutter pub get
flutter run
```

Run the app against your Railway backend:

```powershell
flutter run --dart-define=SOUK_API_URL=https://your-railway-service.up.railway.app
```

`SOUK_API_URL` is required for real signup/login. Without it, the app will not fake authentication.

For Shopify, store owners enter only their Shopify store URL in the seller dashboard. Their Shopify credentials are entered on Shopify's login page.

If `flutter` hangs on this machine, fix the local Flutter SDK first. The app code itself lives in `lib/main.dart` and does not depend on remote packages beyond the default Flutter SDK setup.

## Backend

```bash
cd backend
npm install
cp .env.example .env
npm run db:migrate
npm run db:seed
npm run dev
```

Deploy the backend to Railway with a PostgreSQL database attached. In the backend service variables, add `DATABASE_URL=${{Postgres.DATABASE_URL}}`, replacing `Postgres` if your database service has another name. The included `railway.json` runs migrations before starting the API.
