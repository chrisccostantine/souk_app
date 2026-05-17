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
  }

  async get(path, query = {}) {
    const url = new URL(`https://${this.shopDomain}/admin/api/${this.apiVersion}${path}`);
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.set(key, value);
      }
    }
    const response = await fetch(url, {
      headers: {
        'X-Shopify-Access-Token': this.accessToken,
        'Content-Type': 'application/json',
      },
    });
    return this.#decode(response);
  }

  async post(path, body) {
    const response = await fetch(`https://${this.shopDomain}/admin/api/${this.apiVersion}${path}`, {
      method: 'POST',
      headers: {
        'X-Shopify-Access-Token': this.accessToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    return this.#decode(response);
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

export async function fetchShopifyCatalog(connection) {
  const client = new ShopifyClient(connection);
  const [{ products }, customCollections, smartCollections, locations] = await Promise.all([
    client.get('/products.json', { limit: 250 }),
    client.get('/custom_collections.json', { limit: 250 }),
    client.get('/smart_collections.json', { limit: 250 }),
    client.get('/locations.json', { limit: 250 }),
  ]);

  const collections = [
    ...(customCollections.custom_collections ?? []).map((collection) => ({
      ...collection,
      collectionType: 'CUSTOM',
    })),
    ...(smartCollections.smart_collections ?? []).map((collection) => ({
      ...collection,
      collectionType: 'SMART',
    })),
  ];

  const collects = [];
  for (const collection of collections) {
    const result = await client.get('/collects.json', {
      collection_id: collection.id,
      limit: 250,
    });
    collects.push(...(result.collects ?? []));
  }

  const inventoryItemIds = products
    .flatMap((product) => product.variants ?? [])
    .map((variant) => variant.inventory_item_id)
    .filter(Boolean);
  const inventoryLevels = [];
  for (let index = 0; index < inventoryItemIds.length; index += 50) {
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
    locations: locations.locations ?? [],
  };
}

export async function adjustShopifyInventory({ connection, inventoryItemId, locationId, quantity }) {
  const client = new ShopifyClient(connection);
  return client.post('/inventory_levels/adjust.json', {
    location_id: Number(locationId),
    inventory_item_id: Number(inventoryItemId),
    available_adjustment: -Math.abs(quantity),
  });
}
