import { z } from 'zod';

export const createShopSchema = z.object({
  ownerEmail: z.string().email(),
  ownerName: z.string().min(2),
  name: z.string().min(2),
  category: z.string().min(2),
  city: z.string().min(2),
  story: z.string().min(10),
  minimumOrder: z.coerce.number().min(0).default(0),
  deliveryLabel: z.string().min(2).default('Delivery available'),
});

export const updateShopProfileSchema = z.object({
  logoUrl: z.string().url().optional().nullable(),
  bannerUrl: z.string().url().optional().nullable(),
  primaryColor: z.string().min(4).max(16).optional().nullable(),
  accentColor: z.string().min(4).max(16).optional().nullable(),
  instagramUrl: z.string().url().optional().nullable(),
  tiktokUrl: z.string().url().optional().nullable(),
  websiteUrl: z.string().url().optional().nullable(),
  whatsappPhone: z.string().min(6).optional().nullable(),
  contactEmail: z.string().email().optional().nullable(),
  shippingPolicy: z.string().min(2).optional().nullable(),
  returnPolicy: z.string().min(2).optional().nullable(),
  deliveryLabel: z.string().min(2).optional(),
  minimumOrder: z.coerce.number().min(0).optional(),
  subscriptionPlan: z.enum(['FREE', 'BASIC', 'PRO', 'ENTERPRISE']).optional(),
});

export const followStoreSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).default('Souk customer'),
});

export const analyticsEventSchema = z.object({
  event: z.enum(['view', 'click', 'addToCart', 'order']),
  revenue: z.coerce.number().min(0).optional(),
  topCity: z.string().optional(),
  bestProductId: z.string().optional(),
});

export const createCampaignSchema = z.object({
  channel: z.enum(['PUSH', 'WHATSAPP', 'EMAIL']).default('PUSH'),
  title: z.string().min(2),
  message: z.string().min(2),
  audience: z.string().min(2).default('followers'),
  scheduledAt: z.coerce.date().optional(),
});

export const createPlacementSchema = z.object({
  productId: z.string().optional(),
  title: z.string().min(2),
  placement: z.string().min(2).default('home'),
  budget: z.coerce.number().min(0).default(0),
  status: z.enum(['DRAFT', 'ACTIVE', 'PAUSED', 'ENDED']).default('DRAFT'),
  startsAt: z.coerce.date().optional(),
  endsAt: z.coerce.date().optional(),
});

export const createReviewSchema = z.object({
  customerEmail: z.string().email(),
  customerName: z.string().min(2),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().max(500).optional(),
});

export const favoriteProductSchema = z.object({
  customerEmail: z.string().email(),
  customerName: z.string().min(2),
});

export const aiProductCopySchema = z.object({
  productName: z.string().min(2),
  category: z.string().min(2),
  tone: z.string().default('premium and friendly'),
  keywords: z.string().optional(),
});

export const aiAdCopySchema = z.object({
  storeName: z.string().min(2),
  offer: z.string().min(2),
  channel: z.enum(['instagram', 'push', 'whatsapp']).default('instagram'),
});

export const createDeliveryRegionSchema = z.object({
  name: z.string().min(2),
  fee: z.coerce.number().min(0).default(0),
  eta: z.string().min(2),
  active: z.boolean().default(true),
});

export const createLiveEventSchema = z.object({
  title: z.string().min(2),
  startsAt: z.coerce.date(),
  streamUrl: z.string().url().optional(),
  active: z.boolean().default(false),
});

export const createAffiliateLinkSchema = z.object({
  creatorName: z.string().min(2),
  creatorHandle: z.string().optional(),
  code: z.string().min(3),
  commissionRate: z.coerce.number().min(0).max(100).default(10),
  status: z.enum(['PROPOSED', 'ACTIVE', 'COMPLETED', 'CANCELLED']).default('PROPOSED'),
});

export const verifyShopSchema = z.object({
  verified: z.boolean(),
  verificationNote: z.string().optional(),
});

export const signupSchema = z.object({
  role: z.enum(['CUSTOMER', 'SELLER']),
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(6),
  phone: z.string().optional(),
  store: z.object({
    name: z.string().min(2),
    category: z.string().min(2),
    city: z.string().min(2),
    story: z.string().min(10),
    minimumOrder: z.coerce.number().min(0).default(0),
    deliveryLabel: z.string().min(2).default('Delivery available'),
  }).optional(),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  role: z.enum(['CUSTOMER', 'SELLER']).optional(),
});

export const createProductSchema = z.object({
  shopId: z.string().min(1),
  name: z.string().min(2),
  category: z.string().min(2),
  description: z.string().min(10),
  price: z.coerce.number().positive(),
  stock: z.coerce.number().int().min(0),
  imageUrl: z.string().url().optional(),
});

export const createOrderSchema = z.object({
  customerEmail: z.string().email(),
  customerName: z.string().min(2),
  shopId: z.string().min(1),
  fulfillmentMethod: z.enum(['DELIVERY', 'PICKUP']).default('DELIVERY'),
  paymentMethod: z.enum(['CASH_ON_DELIVERY', 'CARD_ON_DELIVERY', 'WALLET']).default('CASH_ON_DELIVERY'),
  deliveryAddress: z.string().optional(),
  note: z.string().optional(),
  items: z.array(
    z.object({
      productId: z.string().min(1),
      quantity: z.coerce.number().int().positive(),
    }),
  ).min(1),
});

export const updateOrderStatusSchema = z.object({
  status: z.enum([
    'PLACED',
    'ACCEPTED',
    'PACKING',
    'READY',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
    'CANCELLED',
  ]),
});

export const startShopifyOAuthSchema = z.object({
  shopId: z.string().min(1),
  shopDomain: z.string().min(4).optional(),
});

export const syncShopifySchema = z.object({
  shopId: z.string().min(1),
});

export function validate(schema, input) {
  const result = schema.safeParse(input);
  if (!result.success) {
    const error = new Error('Validation failed');
    error.status = 400;
    error.details = result.error.flatten();
    throw error;
  }
  return result.data;
}

export function slugify(value) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
