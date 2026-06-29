import crypto from 'crypto';

export function normalizeShopDomain(domain) {
  return domain
    .replace(/^https?:\/\//, '')
    .replace(/\/.*$/, '')
    .trim()
    .toLowerCase();
}

export function verifyShopifyWebhook({ rawBody, hmac, secret }) {
  if (!secret) {
    return true;
  }
  if (!hmac) {
    return false;
  }
  const digest = crypto
    .createHmac('sha256', secret)
    .update(rawBody, 'utf8')
    .digest('base64');
  const digestBuffer = Buffer.from(digest);
  const hmacBuffer = Buffer.from(hmac);
  if (digestBuffer.length !== hmacBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(digestBuffer, hmacBuffer);
}

export class ShopifyClient {
  constructor({ shopDomain, accessToken, apiVersion = '2026-01' }) {
    this.shopDomain = normalizeShopDomain(shopDomain);
    this.accessToken = accessToken;
    this.apiVersion = apiVersion;
    this.nextRequestAt = 0;
  }

  async get(path, query = {}) {
    const url = new URL(`https://${this.shopDomain}/admin/api/${this.apiVersion}${path}`);
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.set(key, value);
      }
    }
    return this.#request(url, {
      headers: {
        'X-Shopify-Access-Token': this.accessToken,
        'Content-Type': 'application/json',
      },
    });
  }

  async getAll(path, query = {}, bodyKey) {
    const items = [];
    let nextUrl = null;
    do {
      const url = nextUrl ?? new URL(`https://${this.shopDomain}/admin/api/${this.apiVersion}${path}`);
      if (!nextUrl) {
        const requestQuery = {
          ...query,
          limit: query.limit ?? 250,
        };
        for (const [key, value] of Object.entries(requestQuery)) {
          if (value !== undefined && value !== null && value !== '') {
            url.searchParams.set(key, value);
          }
        }
      }
      const result = await this.#requestWithMeta(url, {
        headers: {
          'X-Shopify-Access-Token': this.accessToken,
          'Content-Type': 'application/json',
        },
      });
      items.push(...(result.body[bodyKey] ?? []));
      nextUrl = result.nextUrl;
    } while (nextUrl);
    return items;
  }

  async post(path, body) {
    return this.#request(`https://${this.shopDomain}/admin/api/${this.apiVersion}${path}`, {
      method: 'POST',
      headers: {
        'X-Shopify-Access-Token': this.accessToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
  }

  async graphql(query, variables = {}) {
    return this.#request(`https://${this.shopDomain}/admin/api/${this.apiVersion}/graphql.json`, {
      method: 'POST',
      headers: {
        'X-Shopify-Access-Token': this.accessToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query, variables }),
    });
  }

  async #request(url, options, attempt = 0) {
    const result = await this.#requestWithMeta(url, options, attempt);
    return result.body;
  }

  async #requestWithMeta(url, options, attempt = 0) {
    await this.#throttle();
    const response = await fetch(url, options);
    if (response.status === 429 && attempt < 4) {
      const retryAfter = Number(response.headers.get('retry-after'));
      const waitMs = Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : 1500;
      await delay(waitMs);
      return this.#requestWithMeta(url, options, attempt + 1);
    }
    const body = await this.#decode(response);
    if (body.errors) {
      const error = new Error('Shopify GraphQL request failed');
      error.status = response.status;
      error.details = body.errors;
      throw error;
    }
    return {
      body,
      nextUrl: parseNextUrl(response.headers.get('link')),
    };
  }

  async #throttle() {
    const waitMs = Math.max(this.nextRequestAt - Date.now(), 0);
    if (waitMs > 0) {
      await delay(waitMs);
    }
    this.nextRequestAt = Date.now() + 650;
  }

  async #decode(response) {
    const text = await response.text();
    const body = text ? JSON.parse(text) : {};
    if (!response.ok) {
      const error = new Error(body.errors || body.error || 'Shopify request failed');
      error.status = response.status;
      error.details = body;
      throw error;
    }
    return body;
  }
}

export async function fetchShopifyCatalog(connection, onProgress = () => {}) {
  const client = new ShopifyClient(connection);
  onProgress({ progress: 22, message: 'Downloading Shopify products' });
  const products = await client.getAll('/products.json', { limit: 250 }, 'products');
  onProgress({ progress: 32, message: `Downloaded ${products.length} products` });
  const customCollections = await client.getAll('/custom_collections.json', { limit: 250 }, 'custom_collections');
  onProgress({ progress: 40, message: `Downloaded ${customCollections.length} custom collections` });
  const smartCollections = await client.getAll('/smart_collections.json', { limit: 250 }, 'smart_collections');
  onProgress({ progress: 48, message: `Downloaded ${smartCollections.length} smart collections` });
  const locationsResult = await client.get('/locations.json', { limit: 250 });
  const menu = await fetchShopifyMainMenu(client, onProgress);
  const shippingZones = await fetchShopifyShippingZones(client, onProgress);

  const collections = [
    ...customCollections.map((collection) => ({
      ...collection,
      collectionType: 'CUSTOM',
    })),
    ...smartCollections.map((collection) => ({
      ...collection,
      collectionType: 'SMART',
    })),
  ];

  const collects = [];
  for (let index = 0; index < collections.length; index += 1) {
    const collection = collections[index];
    onProgress({
      progress: Math.min(64, 50 + Math.round((index / Math.max(collections.length, 1)) * 14)),
      message: `Linking collection products ${index + 1}/${collections.length}`,
    });
    if (collection.collectionType === 'CUSTOM') {
      const collectionCollects = await client.getAll('/collects.json', {
        collection_id: collection.id,
        limit: 250,
      }, 'collects');
      collects.push(...collectionCollects);
      continue;
    }

    const collectionProducts = await client.getAll('/products.json', {
      collection_id: collection.id,
      limit: 250,
    }, 'products');
    collects.push(
      ...collectionProducts.map((product) => ({
        collection_id: collection.id,
        product_id: product.id,
      })),
    );
  }

  const inventoryItemIds = products
    .flatMap((product) => product.variants ?? [])
    .map((variant) => variant.inventory_item_id)
    .filter(Boolean);
  const inventoryLevels = [];
  for (let index = 0; index < inventoryItemIds.length; index += 50) {
    onProgress({
      progress: Math.min(70, 64 + Math.round((index / Math.max(inventoryItemIds.length, 1)) * 6)),
      message: `Reading inventory ${Math.min(index + 50, inventoryItemIds.length)}/${inventoryItemIds.length}`,
    });
    const ids = inventoryItemIds.slice(index, index + 50).join(',');
    if (ids) {
      const result = await client.get('/inventory_levels.json', { inventory_item_ids: ids });
      inventoryLevels.push(...(result.inventory_levels ?? []));
    }
  }

  return {
    products,
    collections,
    collects,
    inventoryLevels,
    locations: locationsResult.locations ?? [],
    shippingZones,
    menu,
  };
}

async function fetchShopifyShippingZones(client, onProgress) {
  onProgress({ progress: 50, message: 'Reading Shopify delivery rates' });
  try {
    const result = await client.get('/shipping_zones.json');
    return result.shipping_zones ?? [];
  } catch (error) {
    onProgress({
      progress: 50,
      message: 'Products will sync, but Shopify delivery rates need shipping permission',
    });
    return [];
  }
}

async function fetchShopifyMainMenu(client, onProgress) {
  onProgress({ progress: 49, message: 'Reading Shopify navigation menu' });
  try {
    const result = await client.graphql(`
      query SoukloraMenus {
        menus(first: 20, sortKey: TITLE) {
          nodes {
            id
            title
            handle
            isDefault
            items {
              id
              title
              type
              url
              resourceId
              items {
                id
                title
                type
                url
                resourceId
                items {
                  id
                  title
                  type
                  url
                  resourceId
                }
              }
            }
          }
        }
      }
    `);
    const menus = result.data?.menus?.nodes ?? [];
    const menu =
      menus.find((item) => item.handle === 'main-menu') ??
      menus.find((item) => item.isDefault) ??
      menus.find((item) => item.handle?.includes('main')) ??
      menus[0] ??
      null;
    return menu ? normalizeShopifyMenu(menu) : null;
  } catch (error) {
    onProgress({
      progress: 49,
      message: 'Products will sync, but Shopify menu needs navigation permission',
    });
    return null;
  }
}

function normalizeShopifyMenu(menu) {
  return {
    id: menu.id,
    title: menu.title,
    handle: menu.handle,
    items: normalizeShopifyMenuItems(menu.items ?? []),
  };
}

function normalizeShopifyMenuItems(items) {
  return items.map((item) => ({
    id: item.id,
    title: item.title,
    type: item.type,
    url: item.url,
    resourceId: item.resourceId,
    items: normalizeShopifyMenuItems(item.items ?? []),
  }));
}

export async function adjustShopifyInventory({ connection, inventoryItemId, locationId, quantity }) {
  const client = new ShopifyClient(connection);
  return client.post('/inventory_levels/adjust.json', {
    location_id: Number(locationId),
    inventory_item_id: Number(inventoryItemId),
    available_adjustment: -Math.abs(quantity),
  });
}

export async function createShopifyOrder({ connection, order, items }) {
  const client = new ShopifyClient(connection);
  try {
    return await client.post('/orders.json', {
      order: shopifyOrderPayload({ order, items, useVariantIds: true }),
    });
  } catch (error) {
    if (!shouldRetryShopifyOrderAsCustomItems(error)) {
      throw error;
    }
    return client.post('/orders.json', {
      order: shopifyOrderPayload({ order, items, useVariantIds: false }),
    });
  }
}

function shopifyOrderPayload({ order, items, useVariantIds }) {
  const customerName = splitName(order.customerName || order.customer?.name);
  const phone = shopifyPhone(order.customerPhone || order.customer?.phone);
  return {
    source_name: 'Souklora App',
    financial_status: 'pending',
    currency: order.currency || 'USD',
    email: order.customerEmail || order.customer?.email,
    tags: ['Souklora', 'App Order', `Store: ${order.shop?.name ?? 'Souklora Store'}`].join(', '),
    note: [
      order.note,
      `Souklora store ID: ${order.shopId}`,
      `Souklora store name: ${order.shop?.name ?? ''}`,
      `Buyer user ID: ${order.customerId}`,
      `Payment method: ${order.paymentMethod}`,
      order.city ? `City/area: ${order.city}` : null,
    ].filter(Boolean).join('\n'),
    note_attributes: [
      { name: 'Souklora store ID', value: order.shopId },
      { name: 'Souklora store name', value: order.shop?.name ?? '' },
      { name: 'Buyer user ID', value: order.customerId },
      { name: 'Payment method', value: order.paymentMethod },
      { name: 'Delivery notes', value: order.note ?? '' },
      { name: 'Customer phone', value: order.customerPhone ?? '' },
      { name: 'WhatsApp phone', value: order.whatsappPhone ?? '' },
      { name: 'Souklora item mode', value: useVariantIds ? 'Shopify variants' : 'Custom line items' },
    ],
    shipping_address: {
      first_name: customerName.firstName,
      last_name: customerName.lastName,
      address1: order.deliveryAddress || order.city || 'Souklora delivery address',
      city: order.city || 'Not provided',
      country: 'Lebanon',
      ...(phone ? { phone } : {}),
    },
    line_items: items.map((item) => {
      const variantId = item.variant?.shopifyVariantId ?? item.product?.shopifyVariantId;
      const numericVariantId = Number(variantId);
      const title = item.variant?.title && item.variant.title !== 'Default'
        ? `${item.product?.name ?? 'Souklora product'} - ${item.variant.title}`
        : item.product?.name ?? 'Souklora product';
      if (useVariantIds && Number.isFinite(numericVariantId)) {
        return {
          variant_id: numericVariantId,
          quantity: item.quantity,
        };
      }
      return {
        title,
        quantity: item.quantity,
        price: Number(item.unitPrice).toFixed(2),
        taxable: true,
        requires_shipping: true,
        properties: [
          { name: 'Souklora product ID', value: item.productId },
          { name: 'Souklora variant ID', value: item.variantId ?? '' },
          { name: 'Shopify variant ID', value: variantId ?? '' },
        ],
      };
    }),
    shipping_lines: Number(order.deliveryFee) > 0
      ? [
          {
            title: 'Souklora delivery',
            price: Number(order.deliveryFee).toFixed(2),
            code: 'SOUKLORA_DELIVERY',
            source: 'Souklora App',
          },
        ]
      : [],
  };
}

function shouldRetryShopifyOrderAsCustomItems(error) {
  const text = JSON.stringify(error.details ?? error.message ?? '').toLowerCase();
  return [
    'line_items',
    'variant',
    'price',
    'title',
    'inventory',
    'not found',
  ].some((pattern) => text.includes(pattern));
}

function splitName(name = '') {
  const parts = String(name || 'Souklora Customer').trim().split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] || 'Souklora',
    lastName: parts.slice(1).join(' ') || 'Customer',
  };
}

function shopifyPhone(value) {
  const phone = String(value ?? '').replace(/[\s().-]/g, '');
  return /^\+[1-9]\d{7,14}$/.test(phone) ? phone : null;
}

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function parseNextUrl(linkHeader) {
  if (!linkHeader) {
    return null;
  }
  const nextLink = linkHeader.split(',').find((part) => part.includes('rel="next"'));
  if (!nextLink) {
    return null;
  }
  const match = nextLink.match(/<([^>]+)>/);
  if (!match) {
    return null;
  }
  return new URL(match[1]);
}
