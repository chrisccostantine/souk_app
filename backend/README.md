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
- `GET /api/products`
- `POST /api/products`
- `POST /api/shopify/connect`
- `POST /api/shopify/sync`
- `POST /api/shopify/webhooks/inventory-levels-update`
- `POST /api/shopify/webhooks/products-update`
- `GET /api/orders`
- `POST /api/orders`
- `PATCH /api/orders/:id/status`

## Shopify Sync

Each seller with a Shopify store needs a Shopify Admin API access token. The token should have these scopes:

- `read_products`
- `read_inventory`
- `write_inventory`

Connect a Shopify store:

```http
POST /api/shopify/connect
Content-Type: application/json

{
  "shopId": "souk-shop-id",
  "shopDomain": "merchant-store.myshopify.com",
  "accessToken": "shpat_...",
  "apiVersion": "2026-01"
}
```

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
