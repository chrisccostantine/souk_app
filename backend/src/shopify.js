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
