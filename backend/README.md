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
- `GET /api/shops`
- `POST /api/shops`
- `GET /api/products`
- `POST /api/products`
- `GET /api/orders`
- `POST /api/orders`
- `PATCH /api/orders/:id/status`
