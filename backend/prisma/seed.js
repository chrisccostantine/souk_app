import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

const prisma = new PrismaClient();

function makePasswordSecret(password, salt = crypto.randomBytes(16).toString('hex')) {
  return {
    salt,
    hash: crypto.scryptSync(password, salt, 64).toString('hex'),
  };
}

const shops = [
  {
    owner: { name: 'Cedar Pantry Team', email: 'cedar@souklora.local' },
    name: 'Cedar Pantry',
    slug: 'cedar-pantry',
    category: 'Grocery',
    city: 'Gemmayze',
    story: 'Small-batch pantry staples, roasted nuts, spices, and weekly bundles.',
    rating: 4.9,
    orderCount: 1240,
    minimumOrder: 15,
    deliveryLabel: '45 min delivery',
    products: [
      {
        name: 'Zaatar Breakfast Box',
        slug: 'zaatar-breakfast-box',
        category: 'Grocery',
        description: 'A ready morning box with zaatar, olives, labneh crackers, and roasted nuts.',
        price: 18,
        stock: 18,
        rating: 4.9,
      },
      {
        name: 'Seven Spice Flight',
        slug: 'seven-spice-flight',
        category: 'Grocery',
        description: 'A compact spice set for rice, grills, soups, and weekly cooking.',
        price: 12.5,
        stock: 34,
        rating: 4.8,
      },
    ],
  },
  {
    owner: { name: 'Loom House Team', email: 'loom@souklora.local' },
    name: 'Loom House',
    slug: 'loom-house',
    category: 'Home',
    city: 'Mar Mikhael',
    story: 'Handwoven linens, table pieces, and warm objects for everyday homes.',
    rating: 4.7,
    orderCount: 680,
    minimumOrder: 20,
    deliveryLabel: 'Ships tomorrow',
    products: [
      {
        name: 'Olive Linen Runner',
        slug: 'olive-linen-runner',
        category: 'Home',
        description: 'Handwoven table runner with soft olive tones and a durable daily finish.',
        price: 42,
        stock: 9,
        rating: 4.7,
      },
      {
        name: 'Stackable Ceramic Cups',
        slug: 'stackable-ceramic-cups',
        category: 'Home',
        description: 'Four stackable cups made for small counters, espresso, and tea.',
        price: 28,
        stock: 14,
        rating: 4.6,
      },
    ],
  },
  {
    owner: { name: 'Atelier Nour Team', email: 'nour@souklora.local' },
    name: 'Atelier Nour',
    slug: 'atelier-nour',
    category: 'Fashion',
    city: 'Achrafieh',
    story: 'Independent clothing, jewelry, and accessories from emerging designers.',
    rating: 4.8,
    orderCount: 930,
    minimumOrder: 25,
    deliveryLabel: 'Pickup or courier',
    products: [
      {
        name: 'Printed Silk Scarf',
        slug: 'printed-silk-scarf',
        category: 'Fashion',
        description: 'Light silk scarf with limited-run artwork from an independent designer.',
        price: 54,
        stock: 7,
        rating: 4.9,
      },
      {
        name: 'Amber Body Oil',
        slug: 'amber-body-oil',
        category: 'Beauty',
        description: 'Warm amber body oil blended for daily use, gifting, and travel.',
        price: 24,
        stock: 22,
        rating: 4.8,
      },
    ],
  },
];

async function main() {
  for (const shopData of shops) {
    const owner = await prisma.user.upsert({
      where: { email: shopData.owner.email },
      update: {
        name: shopData.owner.name,
        role: 'SELLER',
        passwordHash: makePasswordSecret('secret1', shopData.owner.email).hash,
        passwordSalt: shopData.owner.email,
      },
      create: {
        name: shopData.owner.name,
        email: shopData.owner.email,
        role: 'SELLER',
        passwordHash: makePasswordSecret('secret1', shopData.owner.email).hash,
        passwordSalt: shopData.owner.email,
      },
    });

    const shop = await prisma.shop.upsert({
      where: { slug: shopData.slug },
      update: {
        name: shopData.name,
        category: shopData.category,
        city: shopData.city,
        story: shopData.story,
        status: 'ACTIVE',
        rating: shopData.rating,
        orderCount: shopData.orderCount,
        minimumOrder: shopData.minimumOrder,
        deliveryLabel: shopData.deliveryLabel,
      },
      create: {
        ownerId: owner.id,
        name: shopData.name,
        slug: shopData.slug,
        category: shopData.category,
        city: shopData.city,
        story: shopData.story,
        status: 'ACTIVE',
        rating: shopData.rating,
        orderCount: shopData.orderCount,
        minimumOrder: shopData.minimumOrder,
        deliveryLabel: shopData.deliveryLabel,
      },
    });

    for (const productData of shopData.products) {
      await prisma.product.upsert({
        where: {
          shopId_slug: {
            shopId: shop.id,
            slug: productData.slug,
          },
        },
        update: {
          name: productData.name,
          category: productData.category,
          description: productData.description,
          price: productData.price,
          stock: productData.stock,
          rating: productData.rating,
          active: true,
        },
        create: {
          shopId: shop.id,
          name: productData.name,
          slug: productData.slug,
          category: productData.category,
          description: productData.description,
          price: productData.price,
          stock: productData.stock,
          rating: productData.rating,
          active: true,
        },
      });
    }
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
