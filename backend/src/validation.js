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
