import 'dotenv/config';
import crypto from 'crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { prisma } from './db.js';
import {
  adjustShopifyInventory,
  fetchShopifyCatalog,
  normalizeShopDomain,
  verifyShopifyWebhook,
} from './shopify.js';
import {
  createOrderSchema,
  createProductSchema,
  createShopSchema,
  loginSchema,
  slugify,
  signupSchema,
  startShopifyOAuthSchema,
  syncShopifySchema,
  updateOrderStatusSchema,
  validate,
} from './validation.js';

const app = express();
const port = process.env.PORT || 8080;
const corsOrigin = process.env.CORS_ORIGIN || '*';
const shopifyScopes = 'read_products,read_inventory,write_inventory';
const oauthStates = new Map();

app.use(helmet());
app.use(cors({ origin: corsOrigin }));
app.use(
  express.json({
    limit: '1mb',
    verify: (req, _res, buf) => {
      req.rawBody = buf.toString('utf8');
    },
  }),
);
app.use(morgan('tiny'));

app.get('/health', async (_req, res, next) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ ok: true, service: 'souk-backend' });
  } catch (error) {
    next(error);
  }
});

function makePasswordSecret(password, salt = crypto.randomBytes(16).toString('hex')) {
  return {
    salt,
    hash: crypto.scryptSync(password, salt, 64).toString('hex'),
  };
}

function passwordMatches(password, user) {
  if (!user.passwordHash || !user.passwordSalt) {
    return false;
  }
  return makePasswordSecret(password, user.passwordSalt).hash === user.passwordHash;
}

function ensureShopifyOAuthConfig() {
  if (!process.env.SHOPIFY_API_KEY || !process.env.SHOPIFY_API_SECRET || !process.env.APP_URL) {
    const error = new Error('Shopify OAuth is not configured');
    error.status = 500;
    throw error;
  }
}

function verifyShopifyOAuthHmac(query, secret) {
  const { hmac, signature, ...rest } = query;
  const message = Object.keys(rest)
    .sort()
    .map((key) => `${key}=${Array.isArray(rest[key]) ? rest[key].join(',') : rest[key]}`)
    .join('&');
  const digest = crypto.createHmac('sha256', secret).update(message).digest('hex');
  const digestBuffer = Buffer.from(digest, 'utf8');
  const hmacBuffer = Buffer.from(String(hmac), 'utf8');
  if (digestBuffer.length !== hmacBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(digestBuffer, hmacBuffer);
}

function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role,
  };
}

app.post('/api/auth/signup', async (req, res, next) => {
  try {
    const input = validate(signupSchema, req.body);

    if (input.role === 'SELLER' && !input.store) {
      const error = new Error('Store details are required for seller signup');
      error.status = 400;
      throw error;
    }

    const existing = await prisma.user.findUnique({ where: { email: input.email } });
    if (existing) {
      const error = new Error('An account with this email already exists');
      error.status = 409;
      throw error;
    }

    const passwordSecret = makePasswordSecret(input.password);
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name: input.name,
          email: input.email,
          phone: input.phone,
          role: input.role,
          passwordHash: passwordSecret.hash,
          passwordSalt: passwordSecret.salt,
        },
      });

      let shop = null;
      if (input.role === 'SELLER') {
        shop = await tx.shop.create({
          data: {
            ownerId: user.id,
            name: input.store.name,
            slug: `${slugify(input.store.name)}-${Date.now().toString(36)}`,
            category: input.store.category,
            city: input.store.city,
            story: input.store.story,
            minimumOrder: input.store.minimumOrder,
            deliveryLabel: input.store.deliveryLabel,
            status: 'DRAFT',
          },
        });
      }

      return { user, shop };
    });

    res.status(201).json({
      user: publicUser(result.user),
      shop: result.shop,
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/auth/login', async (req, res, next) => {
  try {
    const input = validate(loginSchema, req.body);
    const user = await prisma.user.findUnique({
      where: { email: input.email },
      include: { shops: { orderBy: { createdAt: 'desc' }, take: 1 } },
    });

    if (!user || !passwordMatches(input.password, user)) {
      const error = new Error('Invalid email or password');
      error.status = 401;
      throw error;
    }

    if (input.role && user.role !== input.role) {
      const error = new Error(`This account is registered as ${user.role}`);
      error.status = 403;
      throw error;
    }

    res.json({
      user: publicUser(user),
      shop: user.shops[0] ?? null,
    });
  } catch (error) {
    next(error);
  }
});

app.get('/api/shops', async (_req, res, next) => {
  try {
    const shops = await prisma.shop.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        products: {
          where: { active: true },
          orderBy: { createdAt: 'desc' },
          take: 6,
        },
      },
    });
    res.json({ shops });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops', async (req, res, next) => {
  try {
    const input = validate(createShopSchema, req.body);
    const owner = await prisma.user.upsert({
      where: { email: input.ownerEmail },
      update: { name: input.ownerName, role: 'SELLER' },
      create: {
        email: input.ownerEmail,
        name: input.ownerName,
        role: 'SELLER',
      },
    });

    const shop = await prisma.shop.create({
      data: {
        ownerId: owner.id,
        name: input.name,
        slug: `${slugify(input.name)}-${Date.now().toString(36)}`,
        category: input.category,
        city: input.city,
        story: input.story,
        minimumOrder: input.minimumOrder,
        deliveryLabel: input.deliveryLabel,
        status: 'DRAFT',
      },
    });

    res.status(201).json({ shop });
  } catch (error) {
    next(error);
  }
});

app.get('/api/products', async (req, res, next) => {
  try {
    const { category, q, shopId } = req.query;
    const products = await prisma.product.findMany({
      where: {
        active: true,
        ...(shopId ? { shopId: String(shopId) } : {}),
        ...(category ? { category: String(category) } : {}),
        ...(q
          ? {
              OR: [
                { name: { contains: String(q), mode: 'insensitive' } },
                { description: { contains: String(q), mode: 'insensitive' } },
                { shop: { name: { contains: String(q), mode: 'insensitive' } } },
              ],
            }
          : {}),
      },
      include: { shop: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ products });
  } catch (error) {
    next(error);
  }
});

app.post('/api/products', async (req, res, next) => {
  try {
    const input = validate(createProductSchema, req.body);
    const product = await prisma.product.create({
      data: {
        shopId: input.shopId,
        name: input.name,
        slug: `${slugify(input.name)}-${Date.now().toString(36)}`,
        category: input.category,
        description: input.description,
        price: input.price,
        stock: input.stock,
        imageUrl: input.imageUrl,
      },
      include: { shop: true },
    });
    res.status(201).json({ product });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shopify/oauth/start', async (req, res, next) => {
  try {
    const input = validate(startShopifyOAuthSchema, req.body);
    ensureShopifyOAuthConfig();
    if (!input.shopDomain && process.env.SHOPIFY_INSTALL_URL) {
      return res.json({ installUrl: process.env.SHOPIFY_INSTALL_URL, state: null });
    }
    if (!input.shopDomain) {
      const error = new Error('Shopify install URL is not configured');
      error.status = 500;
      throw error;
    }
    const shopDomain = normalizeShopDomain(input.shopDomain);
    const state = crypto.randomBytes(18).toString('hex');
    oauthStates.set(state, {
      shopId: input.shopId,
      shopDomain,
      createdAt: Date.now(),
    });
    const redirectUri = `${process.env.APP_URL}/api/shopify/oauth/callback`;
    const installUrl = new URL(`https://${shopDomain}/admin/oauth/authorize`);
    installUrl.searchParams.set('client_id', process.env.SHOPIFY_API_KEY);
    installUrl.searchParams.set('scope', shopifyScopes);
    installUrl.searchParams.set('redirect_uri', redirectUri);
    installUrl.searchParams.set('state', state);
    res.json({ installUrl: installUrl.toString(), state });
  } catch (error) {
    next(error);
  }
});

app.get('/api/shopify/oauth/callback', async (req, res, next) => {
  try {
    ensureShopifyOAuthConfig();
    const { shop, code, state, hmac, ...rest } = req.query;
    if (!shop || !code || !state || !hmac) {
      const error = new Error('Missing Shopify OAuth callback parameters');
      error.status = 400;
      throw error;
    }
    if (!verifyShopifyOAuthHmac(req.query, process.env.SHOPIFY_API_SECRET)) {
      const error = new Error('Invalid Shopify OAuth signature');
      error.status = 401;
      throw error;
    }
    const stateData = oauthStates.get(String(state));
    oauthStates.delete(String(state));
    if (!stateData || Date.now() - stateData.createdAt > 10 * 60 * 1000) {
      const error = new Error('Shopify OAuth state expired');
      error.status = 401;
      throw error;
    }
    const shopDomain = normalizeShopDomain(String(shop));
    const tokenResponse = await fetch(`https://${shopDomain}/admin/oauth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.SHOPIFY_API_KEY,
        client_secret: process.env.SHOPIFY_API_SECRET,
        code,
      }),
    });
    const tokenBody = await tokenResponse.json();
    if (!tokenResponse.ok) {
      const error = new Error('Shopify token exchange failed');
      error.status = tokenResponse.status;
      error.details = tokenBody;
      throw error;
    }
    await prisma.shopifyConnection.upsert({
      where: { shopId: stateData.shopId },
      update: {
        shopDomain,
        accessToken: tokenBody.access_token,
        apiVersion: process.env.SHOPIFY_API_VERSION || '2026-01',
      },
      create: {
        shopId: stateData.shopId,
        shopDomain,
        accessToken: tokenBody.access_token,
        apiVersion: process.env.SHOPIFY_API_VERSION || '2026-01',
      },
    });
    res.send('Shopify connected. You can return to Souk and sync products.');
  } catch (error) {
    next(error);
  }
});

app.post('/api/shopify/sync', async (req, res, next) => {
  try {
    const input = validate(syncShopifySchema, req.body);
    const connection = await prisma.shopifyConnection.findUnique({
      where: { shopId: input.shopId },
    });
    if (!connection) {
      const error = new Error('Shopify is not connected for this shop');
      error.status = 404;
      throw error;
    }

    const catalog = await fetchShopifyCatalog(connection);
    const result = await upsertShopifyCatalog(input.shopId, connection, catalog);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

app.get('/api/orders', async (req, res, next) => {
  try {
    const { customerEmail, shopId } = req.query;
    const orders = await prisma.order.findMany({
      where: {
        ...(shopId ? { shopId: String(shopId) } : {}),
        ...(customerEmail ? { customer: { email: String(customerEmail) } } : {}),
      },
      include: {
        customer: true,
        shop: true,
        items: { include: { product: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ orders });
  } catch (error) {
    next(error);
  }
});

app.post('/api/orders', async (req, res, next) => {
  try {
    const input = validate(createOrderSchema, req.body);
    const products = await prisma.product.findMany({
      where: { id: { in: input.items.map((item) => item.productId) } },
    });

    if (products.length !== input.items.length) {
      const error = new Error('One or more products were not found');
      error.status = 404;
      throw error;
    }

    const subtotal = input.items.reduce((sum, item) => {
      const product = products.find((current) => current.id === item.productId);
      return sum + Number(product.price) * item.quantity;
    }, 0);
    const deliveryFee = input.fulfillmentMethod === 'DELIVERY' ? 3.5 : 0;
    const total = subtotal + deliveryFee;

    const order = await prisma.$transaction(async (tx) => {
      const customer = await tx.user.upsert({
        where: { email: input.customerEmail },
        update: { name: input.customerName },
        create: {
          email: input.customerEmail,
          name: input.customerName,
          role: 'CUSTOMER',
        },
      });

      return tx.order.create({
        data: {
          customerId: customer.id,
          shopId: input.shopId,
          fulfillmentMethod: input.fulfillmentMethod,
          paymentMethod: input.paymentMethod,
          deliveryAddress: input.deliveryAddress,
          note: input.note,
          subtotal,
          deliveryFee,
          total,
          items: {
            create: input.items.map((item) => {
              const product = products.find((current) => current.id === item.productId);
              return {
                productId: item.productId,
                quantity: item.quantity,
                unitPrice: product.price,
              };
            }),
          },
        },
        include: {
          customer: true,
          shop: true,
          items: { include: { product: true } },
        },
      });
    });

    const shopifyUpdates = await syncSoukOrderToShopifyInventory(input.shopId, order.items);
    res.status(201).json({ order });
    if (shopifyUpdates.failed.length > 0) {
      console.warn('Some Shopify inventory updates failed', shopifyUpdates.failed);
    }
  } catch (error) {
    next(error);
  }
});

app.patch('/api/orders/:id/status', async (req, res, next) => {
  try {
    const input = validate(updateOrderStatusSchema, req.body);
    const order = await prisma.order.update({
      where: { id: req.params.id },
      data: { status: input.status },
      include: {
        customer: true,
        shop: true,
        items: { include: { product: true } },
      },
    });
    res.json({ order });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shopify/webhooks/inventory-levels-update', async (req, res, next) => {
  try {
    const valid = verifyShopifyWebhook({
      rawBody: req.rawBody,
      hmac: req.get('X-Shopify-Hmac-Sha256'),
      secret: process.env.SHOPIFY_WEBHOOK_SECRET,
    });
    if (!valid) {
      return res.status(401).json({ error: 'Invalid Shopify webhook signature' });
    }

    const payload = req.body;
    if (payload.inventory_item_id) {
      await prisma.product.updateMany({
        where: { shopifyInventoryItemId: String(payload.inventory_item_id) },
        data: {
          stock: Number(payload.available ?? 0),
          shopifyLocationId: payload.location_id ? String(payload.location_id) : undefined,
          lastSyncedAt: new Date(),
        },
      });
    }
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

app.post('/api/shopify/webhooks/products-update', async (req, res, next) => {
  try {
    const valid = verifyShopifyWebhook({
      rawBody: req.rawBody,
      hmac: req.get('X-Shopify-Hmac-Sha256'),
      secret: process.env.SHOPIFY_WEBHOOK_SECRET,
    });
    if (!valid) {
      return res.status(401).json({ error: 'Invalid Shopify webhook signature' });
    }

    const product = req.body;
    const variant = product.variants?.[0];
    if (product.id && variant) {
      await prisma.product.updateMany({
        where: { shopifyProductId: String(product.id) },
        data: {
          name: product.title,
          description: stripHtml(product.body_html ?? ''),
          price: Number(variant.price ?? 0),
          imageUrl: product.image?.src,
          shopifyVariantId: String(variant.id),
          shopifyInventoryItemId: String(variant.inventory_item_id),
          lastSyncedAt: new Date(),
        },
      });
    }
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

async function upsertShopifyCatalog(shopId, connection, catalog) {
  const now = new Date();
  const inventoryByItemId = new Map(
    catalog.inventoryLevels.map((level) => [String(level.inventory_item_id), level]),
  );
  const productByShopifyId = new Map();

  for (const collection of catalog.collections) {
    await prisma.collection.upsert({
      where: {
        shopId_slug: {
          shopId,
          slug: slugify(collection.handle || collection.title),
        },
      },
      update: {
        title: collection.title,
        description: stripHtml(collection.body_html ?? ''),
        imageUrl: collection.image?.src,
        shopifyCollectionId: String(collection.id),
        collectionType: collection.collectionType,
      },
      create: {
        shopId,
        title: collection.title,
        slug: slugify(collection.handle || collection.title),
        description: stripHtml(collection.body_html ?? ''),
        imageUrl: collection.image?.src,
        shopifyCollectionId: String(collection.id),
        collectionType: collection.collectionType,
      },
    });
  }

  for (const shopifyProduct of catalog.products) {
    const variant = shopifyProduct.variants?.[0];
    if (!variant) {
      continue;
    }
    const inventoryLevel = inventoryByItemId.get(String(variant.inventory_item_id));
    const product = await prisma.product.upsert({
      where: {
        shopId_slug: {
          shopId,
          slug: slugify(shopifyProduct.handle || shopifyProduct.title),
        },
      },
      update: {
        name: shopifyProduct.title,
        category: shopifyProduct.product_type || 'Shopify',
        description: stripHtml(shopifyProduct.body_html ?? ''),
        price: Number(variant.price ?? 0),
        stock: Number(inventoryLevel?.available ?? variant.inventory_quantity ?? 0),
        imageUrl: shopifyProduct.image?.src,
        active: shopifyProduct.status === 'active',
        shopifyProductId: String(shopifyProduct.id),
        shopifyVariantId: String(variant.id),
        shopifyInventoryItemId: String(variant.inventory_item_id),
        shopifyLocationId: inventoryLevel?.location_id ? String(inventoryLevel.location_id) : null,
        syncedFrom: 'SHOPIFY',
        lastSyncedAt: now,
      },
      create: {
        shopId,
        name: shopifyProduct.title,
        slug: slugify(shopifyProduct.handle || shopifyProduct.title),
        category: shopifyProduct.product_type || 'Shopify',
        description: stripHtml(shopifyProduct.body_html ?? ''),
        price: Number(variant.price ?? 0),
        stock: Number(inventoryLevel?.available ?? variant.inventory_quantity ?? 0),
        imageUrl: shopifyProduct.image?.src,
        active: shopifyProduct.status === 'active',
        shopifyProductId: String(shopifyProduct.id),
        shopifyVariantId: String(variant.id),
        shopifyInventoryItemId: String(variant.inventory_item_id),
        shopifyLocationId: inventoryLevel?.location_id ? String(inventoryLevel.location_id) : null,
        syncedFrom: 'SHOPIFY',
        lastSyncedAt: now,
      },
    });
    productByShopifyId.set(String(shopifyProduct.id), product);
  }

  for (const collect of catalog.collects) {
    const product = productByShopifyId.get(String(collect.product_id));
    if (!product) {
      continue;
    }
    const collection = await prisma.collection.findFirst({
      where: {
        shopId,
        shopifyCollectionId: String(collect.collection_id),
      },
    });
    if (collection) {
      await prisma.productCollection.upsert({
        where: {
          productId_collectionId: {
            productId: product.id,
            collectionId: collection.id,
          },
        },
        update: {},
        create: {
          productId: product.id,
          collectionId: collection.id,
        },
      });
    }
  }

  await prisma.shopifyConnection.update({
    where: { id: connection.id },
    data: {
      defaultLocationId: catalog.locations[0]?.id ? String(catalog.locations[0].id) : connection.defaultLocationId,
      lastSyncedAt: now,
    },
  });

  return {
    syncedAt: now,
    products: productByShopifyId.size,
    collections: catalog.collections.length,
  };
}

function stripHtml(value) {
  return value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

async function syncSoukOrderToShopifyInventory(shopId, orderItems) {
  const connection = await prisma.shopifyConnection.findUnique({ where: { shopId } });
  if (!connection) {
    return { updated: [], failed: [] };
  }

  const updated = [];
  const failed = [];
  for (const item of orderItems) {
    const product = item.product;
    if (!product.shopifyInventoryItemId) {
      continue;
    }
    const locationId = product.shopifyLocationId || connection.defaultLocationId;
    if (!locationId) {
      failed.push({ productId: product.id, reason: 'Missing Shopify location id' });
      continue;
    }
    try {
      const result = await adjustShopifyInventory({
        connection,
        inventoryItemId: product.shopifyInventoryItemId,
        locationId,
        quantity: item.quantity,
      });
      const available = result.inventory_level?.available;
      await prisma.product.update({
        where: { id: product.id },
        data: {
          stock: typeof available === 'number' ? available : Math.max(product.stock - item.quantity, 0),
          lastSyncedAt: new Date(),
        },
      });
      updated.push(product.id);
    } catch (error) {
      failed.push({ productId: product.id, reason: error.message });
    }
  }
  return { updated, failed };
}

app.use((req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

app.use((error, _req, res, _next) => {
  const status = error.status || 500;
  res.status(status).json({
    error: error.message || 'Internal server error',
    details: error.details,
  });
});

app.listen(port, () => {
  console.log(`Souk API listening on port ${port}`);
});
