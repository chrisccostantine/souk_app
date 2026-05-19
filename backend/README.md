# Souk Backend

Railway-ready API for the Souk marketplace app.

## Stack

- Node.js and Express
- PostgreSQL
- Prisma ORM
- Zod validation

## Local Setup

```bash
cd backend
cp .env.example .env
npm install
npm run db:migrate
npm run db:seed
npm run dev
```

The API runs on `http://localhost:8080` by default.

## Railway Setup

1. Create a Railway project.
2. Add a PostgreSQL database.
3. Add this `backend` folder as a Railway service.
4. In the backend service, open **Variables** and add a reference variable:

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

If your PostgreSQL service has a different name, replace `Postgres` with that exact service name.

5. Deploy. Railway will run:

```bash
npm run db:deploy && npm start
```

## Useful Endpoints

- `GET /health`
- `POST /api/auth/signup`
- `POST /api/auth/login`
- `GET /api/shops`
- `POST /api/shops`
- `GET /api/shops/:id/inventory`
- `GET /api/products`
- `POST /api/products`
- `POST /api/shopify/oauth/start`
- `GET /api/shopify/oauth/callback`
- `POST /api/shopify/sync`
- `POST /api/shopify/webhooks/inventory-levels-update`
- `POST /api/shopify/webhooks/products-update`
- `GET /api/orders`
- `POST /api/orders`
- `PATCH /api/orders/:id/status`

## Shopify Sync

Each seller connects Shopify through Shopify OAuth. They should not paste an Admin API token into the mobile app. Configure these Railway variables from your Shopify app:

```text
SHOPIFY_API_KEY=...
SHOPIFY_API_SECRET=...
SHOPIFY_API_VERSION=2026-01
APP_URL=https://your-railway-service.up.railway.app
```

## Password Reset Email

Forgot-password codes can be emailed through Resend over HTTPS. This avoids SMTP connection timeouts on Railway.

```text
RESEND_API_KEY=re_...
RESEND_FROM=Souk <onboarding@resend.dev>
```

SMTP is also supported as a fallback:

```text
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=Souk <your-email@gmail.com>
```

For Gmail, `SMTP_PASS` must be an app password, not your normal Gmail password.

## Social Login

Google and Apple sign-in use mobile identity tokens. Optional backend verification variables:

```text
GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
APPLE_CLIENT_ID=your-apple-service-or-bundle-id
```

For Android Google sign-in, run the Flutter app with:

```text
--dart-define=GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
```

For Android Apple sign-in, also provide:

```text
--dart-define=APPLE_SERVICE_ID=your-apple-service-id
--dart-define=APPLE_REDIRECT_URI=https://your-apple-redirect-uri
```

Your Shopify app should request these scopes:

- `read_products`
- `read_inventory`
- `write_inventory`
- `read_locations`

Start Shopify connection:

```http
POST /api/shopify/oauth/start
Content-Type: application/json

{
  "shopId": "souk-shop-id"
}
```

The response includes an `installUrl`. Open that URL so the seller logs in with Shopify and approves access. Shopify then redirects to:

```text
/api/shopify/oauth/callback
```

The mobile app asks only for the Shopify store URL, for example `merchant-store.myshopify.com`. The seller's Shopify credentials are entered only on Shopify's login page.

After OAuth succeeds, the callback page tries to reopen the app with:

```text
souk://shopify-connected
```

The mobile app also checks `/api/shopify/status` whenever it returns from the browser, so it can mark the store as connected even if the browser cannot auto-open the app.

Shopify now requires expiring offline access tokens for Admin API calls. If an older connection shows a non-expiring token error, reconnect the Shopify store once so Souk can store the refresh token.

Sync catalog, collections, images, descriptions, prices, and inventory:

```http
POST /api/shopify/sync
Content-Type: application/json

{
  "shopId": "souk-shop-id"
}
```

For two-way inventory:

- Souk orders call Shopify inventory adjustment for synced products.
- Shopify inventory webhooks update Souk product stock.
- Add `SHOPIFY_WEBHOOK_SECRET` in Railway if webhook signature verification is enabled.

Recommended Shopify webhook topics:

- `inventory_levels/update` -> `/api/shopify/webhooks/inventory-levels-update`
- `products/update` -> `/api/shopify/webhooks/products-update`
