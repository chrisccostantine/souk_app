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

  async #request(url, options, attempt = 0) {
    await this.#throttle();
    const response = await fetch(url, options);
    if (response.status === 429 && attempt < 4) {
      const retryAfter = Number(response.headers.get('retry-after'));
      const waitMs = Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : 1500;
      await delay(waitMs);
      return this.#request(url, options, attempt + 1);
    }
    return this.#decode(response);
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

export async function fetchShopifyCatalog(connection) {
  const client = new ShopifyClient(connection);
  const { products } = await client.get('/products.json', { limit: 250 });
  const customCollections = await client.get('/custom_collections.json', { limit: 250 });
  const smartCollections = await client.get('/smart_collections.json', { limit: 250 });
  const locations = await client.get('/locations.json', { limit: 250 });

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
    if (collection.collectionType === 'CUSTOM') {
      const result = await client.get('/collects.json', {
        collection_id: collection.id,
        limit: 250,
      });
      collects.push(...(result.collects ?? []));
      continue;
    }

    const result = await client.get('/products.json', {
      collection_id: collection.id,
      limit: 250,
    });
    collects.push(
      ...(result.products ?? []).map((product) => ({
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

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
