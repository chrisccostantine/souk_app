import 'dotenv/config';
import crypto from 'crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import nodemailer from 'nodemailer';
import { prisma } from './db.js';
import { sendPushToTokens } from './notifications.js';
import {
  adjustShopifyInventory,
  fetchShopifyCatalog,
  normalizeShopDomain,
  verifyShopifyWebhook,
} from './shopify.js';
import {
  analyticsEventSchema,
  aiAdCopySchema,
  aiProductCopySchema,
  changePasswordSchema,
  confirmPasswordResetSchema,
  createAffiliateLinkSchema,
  createCampaignSchema,
  createDeliveryRegionSchema,
  createLiveEventSchema,
  createOrderSchema,
  createPlacementSchema,
  createProductSchema,
  createReviewSchema,
  createStoreStorySchema,
  favoriteProductSchema,
  forgotPasswordSchema,
  createShopSchema,
  followStoreSchema,
  loginSchema,
  registerDeviceTokenSchema,
  slugify,
  socialAuthSchema,
  signupSchema,
  startShopifyOAuthSchema,
  syncShopifySchema,
  updateOrderStatusSchema,
  updateShopProfileSchema,
  verifyShopSchema,
  validate,
} from './validation.js';

const app = express();
const port = process.env.PORT || 8080;
const corsOrigin = process.env.CORS_ORIGIN || '*';
const requiredShopifyScopes = [
  'read_products',
  'read_inventory',
  'write_inventory',
  'read_locations',
  'read_online_store_navigation',
];
const shopifyScopes = requiredShopifyScopes.join(',');
const oauthStates = new Map();
const shopifySyncJobs = new Map();
const passwordResetCodes = new Map();

app.use(helmet());
app.use(cors({ origin: corsOrigin }));
app.use(
  express.json({
    limit: '6mb',
    verify: (req, _res, buf) => {
      req.rawBody = buf.toString('utf8');
    },
  }),
);
app.use(morgan('tiny'));

app.get('/health', async (_req, res, next) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ ok: true, service: 'souklora-backend' });
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

function requireResetEmailConfig() {
  if (process.env.RESEND_API_KEY && process.env.RESEND_FROM) {
    return;
  }
  const required = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM'];
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    const error = new Error(`Password reset email is not configured. Add RESEND_API_KEY and RESEND_FROM, or missing SMTP variables: ${missing.join(', ')}`);
    error.status = 500;
    throw error;
  }
}

function resetEmailText(name, resetCode) {
  return `Hi ${name || 'there'},\n\nYour Souklora password reset code is ${resetCode}.\n\nThis code expires in 10 minutes. If you did not request this, you can ignore this email.`;
}

function resetEmailHtml(name, resetCode) {
  return `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#17211B">
      <h2>Your Souklora reset code</h2>
      <p>Hi ${name || 'there'},</p>
      <p>Use this code to reset your password:</p>
      <div style="font-size:28px;font-weight:800;letter-spacing:4px;margin:16px 0">${resetCode}</div>
      <p>This code expires in 10 minutes. If you did not request this, you can ignore this email.</p>
    </div>
  `;
}

function smtpValue(key) {
  return String(process.env[key] ?? '').trim();
}

function withTimeout(promise, milliseconds, message) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => reject(new Error(message)), milliseconds);
    }),
  ]);
}

function emailSendError(error) {
  const message = String(error?.message ?? error);
  if (message.includes('Resend')) {
    return message;
  }
  if (message.includes('timed out') || message.includes('ETIMEDOUT') || message.includes('ECONNECTION')) {
    return 'Could not connect to Gmail SMTP from Railway. Use RESEND_API_KEY and RESEND_FROM instead of SMTP.';
  }
  if (message.includes('Invalid login') || message.includes('EAUTH') || message.includes('Username and Password')) {
    return 'Gmail rejected the SMTP login. Use the exact Gmail in SMTP_USER and paste SMTP_PASS without spaces.';
  }
  return `Could not send the password reset email: ${message}`;
}

async function sendPasswordResetEmailWithResend({ to, name, resetCode }) {
  const response = await withTimeout(
    fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.RESEND_FROM,
        to,
        subject: 'Your Souklora password reset code',
        text: resetEmailText(name, resetCode),
        html: resetEmailHtml(name, resetCode),
      }),
    }),
    9000,
    'Resend email send timed out',
  );
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = body?.message || body?.error || `Resend failed with HTTP ${response.status}`;
    const error = new Error(`Resend email failed: ${message}`);
    error.status = 502;
    throw error;
  }
}

async function sendPasswordResetEmail({ to, name, resetCode }) {
  requireResetEmailConfig();
  if (process.env.RESEND_API_KEY && process.env.RESEND_FROM) {
    try {
      await sendPasswordResetEmailWithResend({ to, name, resetCode });
      return;
    } catch (error) {
      console.error('Password reset email failed', {
        provider: 'resend',
        status: error?.status,
        message: error?.message,
      });
      const sendError = new Error(emailSendError(error));
      sendError.status = error?.status || 502;
      throw sendError;
    }
  }
  const smtpUser = smtpValue('SMTP_USER');
  const smtpPass = smtpValue('SMTP_PASS').replace(/\s+/g, '');
  const smtpFrom = smtpValue('SMTP_FROM');
  const transporter = nodemailer.createTransport({
    host: smtpValue('SMTP_HOST'),
    port: Number(smtpValue('SMTP_PORT')),
    secure: String(process.env.SMTP_SECURE ?? '').toLowerCase() === 'true' || Number(smtpValue('SMTP_PORT')) === 465,
    connectionTimeout: 6000,
    greetingTimeout: 6000,
    socketTimeout: 8000,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  try {
    await withTimeout(
      transporter.sendMail({
        from: smtpFrom,
        to,
        subject: 'Your Souklora password reset code',
        text: resetEmailText(name, resetCode),
        html: resetEmailHtml(name, resetCode),
      }),
      9000,
      'Email send timed out',
    );
  } catch (error) {
    console.error('Password reset email failed', {
      code: error?.code,
      command: error?.command,
      responseCode: error?.responseCode,
      message: error?.message,
    });
    const sendError = new Error(emailSendError(error));
    sendError.status = 502;
    throw sendError;
  }
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

function tokenExpiresAt(seconds) {
  return seconds ? new Date(Date.now() + Number(seconds) * 1000) : null;
}

function shopifyTokenData(tokenBody) {
  return {
    accessToken: tokenBody.access_token,
    refreshToken: tokenBody.refresh_token ?? null,
    accessTokenExpiresAt: tokenExpiresAt(tokenBody.expires_in),
    refreshTokenExpiresAt: tokenExpiresAt(tokenBody.refresh_token_expires_in),
    scopes: tokenBody.scope ?? tokenBody.associated_user_scope ?? null,
  };
}

function shopifyTokenRequestBody(values) {
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null) {
      body.set(key, String(value));
    }
  }
  return body;
}

async function exchangeShopifyToken(shopDomain, values) {
  const tokenResponse = await fetch(`https://${shopDomain}/admin/oauth/access_token`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: shopifyTokenRequestBody(values),
  });
  const tokenBody = await tokenResponse.json();
  if (!tokenResponse.ok) {
    const error = new Error('Shopify token exchange failed');
    error.status = tokenResponse.status;
    error.details = tokenBody;
    throw error;
  }
  return tokenBody;
}

async function refreshShopifyConnection(connection) {
  ensureShopifyOAuthConfig();
  if (!connection.refreshToken) {
    const error = new Error('Reconnect Shopify to upgrade this store to expiring offline tokens');
    error.status = 409;
    throw error;
  }

  const shouldRefresh =
    connection.accessTokenExpiresAt &&
    connection.accessTokenExpiresAt.getTime() <= Date.now() + 60 * 1000;
  if (!shouldRefresh) {
    return connection;
  }

  const tokenBody = await exchangeShopifyToken(connection.shopDomain, {
    client_id: process.env.SHOPIFY_API_KEY,
    client_secret: process.env.SHOPIFY_API_SECRET,
    grant_type: 'refresh_token',
    refresh_token: connection.refreshToken,
  });

  return prisma.shopifyConnection.update({
    where: { id: connection.id },
    data: shopifyTokenData(tokenBody),
  });
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

function decodeJwtPayload(token) {
  const [, payload] = String(token).split('.');
  if (!payload) {
    const error = new Error('Invalid identity token');
    error.status = 401;
    throw error;
  }
  try {
    return JSON.parse(Buffer.from(payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
  } catch {
    const error = new Error('Invalid identity token');
    error.status = 401;
    throw error;
  }
}

async function verifyGoogleIdentity(idToken) {
  const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.email || body.email_verified !== 'true') {
    const error = new Error('Google sign-in could not be verified');
    error.status = 401;
    throw error;
  }
  if (process.env.GOOGLE_CLIENT_ID && body.aud !== process.env.GOOGLE_CLIENT_ID) {
    const error = new Error('Google sign-in is not configured for this app');
    error.status = 401;
    throw error;
  }
  return {
    email: String(body.email).toLowerCase(),
    name: body.name || body.given_name || String(body.email).split('@')[0],
  };
}

function verifyAppleIdentity(idToken, fallback) {
  const payload = decodeJwtPayload(idToken);
  if (!payload.email && !fallback.email) {
    const error = new Error('Apple did not provide an email for this account');
    error.status = 401;
    throw error;
  }
  if (payload.exp && Number(payload.exp) * 1000 < Date.now()) {
    const error = new Error('Apple sign-in token expired');
    error.status = 401;
    throw error;
  }
  if (process.env.APPLE_CLIENT_ID && payload.aud !== process.env.APPLE_CLIENT_ID) {
    const error = new Error('Apple sign-in is not configured for this app');
    error.status = 401;
    throw error;
  }
  const email = String(payload.email || fallback.email).toLowerCase();
  return {
    email,
    name: fallback.name || email.split('@')[0],
  };
}

async function socialProfile(input) {
  if (input.provider === 'GOOGLE') {
    return verifyGoogleIdentity(input.idToken);
  }
  return verifyAppleIdentity(input.idToken, input);
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

app.post('/api/auth/social', async (req, res, next) => {
  try {
    const input = validate(socialAuthSchema, req.body);
    const profile = await socialProfile(input);
    const existing = await prisma.user.findUnique({
      where: { email: profile.email },
      include: { shops: { orderBy: { createdAt: 'desc' }, take: 1 } },
    });
    if (existing?.role === 'SELLER') {
      const error = new Error('Store accounts must login with email and password');
      error.status = 403;
      throw error;
    }
    const user = existing
      ? await prisma.user.update({
          where: { id: existing.id },
          data: { name: profile.name || existing.name },
          include: { shops: { orderBy: { createdAt: 'desc' }, take: 1 } },
        })
      : await prisma.user.create({
          data: {
            email: profile.email,
            name: profile.name,
            role: 'CUSTOMER',
          },
          include: { shops: { orderBy: { createdAt: 'desc' }, take: 1 } },
        });

    res.json({
      user: publicUser(user),
      shop: user.shops[0] ?? null,
    });
  } catch (error) {
    next(error);
  }
});

async function changePassword(req, res, next) {
  try {
    const input = validate(changePasswordSchema, req.body);
    const user = await prisma.user.findUnique({ where: { email: input.email } });

    if (!user || !passwordMatches(input.currentPassword, user)) {
      const error = new Error('Current password is incorrect');
      error.status = 401;
      throw error;
    }

    const passwordSecret = makePasswordSecret(input.newPassword);
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: passwordSecret.hash,
        passwordSalt: passwordSecret.salt,
      },
    });

    res.json({ ok: true, message: 'Password updated' });
  } catch (error) {
    next(error);
  }
}

async function forgotPassword(req, res, next) {
  try {
    const input = validate(forgotPasswordSchema, req.body);
    const user = await prisma.user.findUnique({ where: { email: input.email } });

    if (!user) {
      const error = new Error('No account was found for this email');
      error.status = 404;
      throw error;
    }

    const resetCode = crypto.randomInt(100000, 999999).toString();
    passwordResetCodes.set(input.email.toLowerCase(), {
      code: resetCode,
      expiresAt: Date.now() + 10 * 60 * 1000,
    });
    await sendPasswordResetEmail({
      to: user.email,
      name: user.name,
      resetCode,
    });

    res.json({
      ok: true,
      message: 'Password reset code sent by email.',
    });
  } catch (error) {
    next(error);
  }
}

async function confirmPasswordReset(req, res, next) {
  try {
    const input = validate(confirmPasswordResetSchema, req.body);
    const reset = passwordResetCodes.get(input.email.toLowerCase());
    if (!reset || reset.code !== input.resetCode || reset.expiresAt < Date.now()) {
      const error = new Error('Reset code is invalid or expired');
      error.status = 400;
      throw error;
    }

    const user = await prisma.user.findUnique({ where: { email: input.email } });
    if (!user) {
      const error = new Error('No account was found for this email');
      error.status = 404;
      throw error;
    }

    const passwordSecret = makePasswordSecret(input.newPassword);
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: passwordSecret.hash,
        passwordSalt: passwordSecret.salt,
      },
    });
    passwordResetCodes.delete(input.email.toLowerCase());

    res.json({ ok: true, message: 'Password updated' });
  } catch (error) {
    next(error);
  }
}

app.post('/api/auth/change-password', changePassword);
app.post('/api/auth/password/change', changePassword);
app.post('/api/auth/forgot-password', forgotPassword);
app.post('/api/auth/password/forgot', forgotPassword);
app.post('/api/auth/reset-password', forgotPassword);
app.post('/api/auth/reset-password/confirm', confirmPasswordReset);
app.post('/api/auth/password/reset/confirm', confirmPasswordReset);

app.get('/api/shops', async (req, res, next) => {
  try {
    const shops = await prisma.shop.findMany({
      where: req.query.includeAll === 'true' ? {} : { status: 'ACTIVE', verified: true },
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

app.get('/api/stories', async (req, res, next) => {
  try {
    const now = new Date();
    await prisma.storeStory.deleteMany({
      where: { expiresAt: { lte: now } },
    });
    const stories = await prisma.storeStory.findMany({
      where: {
        expiresAt: { gt: now },
        shop: { status: 'ACTIVE', verified: true },
      },
      include: { shop: true },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    res.json({ stories });
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

app.post('/api/shops/:id/stories', async (req, res, next) => {
  try {
    const input = validate(createStoreStorySchema, req.body);
    const now = new Date();
    const story = await prisma.storeStory.create({
      data: {
        shopId: String(req.params.id),
        title: input.title,
        caption: input.caption,
        imageUrl: input.imageUrl,
        expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000),
      },
      include: { shop: true },
    });
    res.status(201).json({ story });
  } catch (error) {
    next(error);
  }
});

app.patch('/api/shops/:id/profile', async (req, res, next) => {
  try {
    const input = validate(updateShopProfileSchema, req.body);
    const shop = await prisma.shop.update({
      where: { id: String(req.params.id) },
      data: input,
    });
    res.json({ shop });
  } catch (error) {
    next(error);
  }
});

app.get('/api/shops/:id/growth', async (req, res, next) => {
  try {
    const shopId = String(req.params.id);
    const [shop, analytics, followers, loyaltyAccounts, campaigns, placements] = await Promise.all([
      prisma.shop.findUnique({
        where: { id: shopId },
        select: { rating: true, orderCount: true },
      }),
      prisma.storeAnalyticsDaily.findMany({
        where: { shopId },
        orderBy: { day: 'desc' },
        take: 30,
      }),
      prisma.storeFollow.count({ where: { shopId } }),
      prisma.loyaltyAccount.count({ where: { shopId } }),
      prisma.notificationCampaign.findMany({
        where: { shopId },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
      prisma.sponsoredPlacement.findMany({
        where: { shopId },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);
    res.json({
      analytics,
      followers,
      loyaltyAccounts,
      campaigns,
      placements,
      rating: shop?.rating ?? 0,
      orderCount: shop?.orderCount ?? 0,
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/delivery-regions', async (req, res, next) => {
  try {
    const input = validate(createDeliveryRegionSchema, req.body);
    const region = await prisma.deliveryRegion.create({
      data: { ...input, shopId: String(req.params.id) },
    });
    res.status(201).json({ region });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/live-events', async (req, res, next) => {
  try {
    const input = validate(createLiveEventSchema, req.body);
    const event = await prisma.liveSellingEvent.create({
      data: { ...input, shopId: String(req.params.id) },
    });
    res.status(201).json({ event });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/affiliate-links', async (req, res, next) => {
  try {
    const input = validate(createAffiliateLinkSchema, req.body);
    const link = await prisma.affiliateLink.create({
      data: { ...input, shopId: String(req.params.id) },
    });
    res.status(201).json({ link });
  } catch (error) {
    next(error);
  }
});

app.patch('/api/admin/shops/:id/verification', async (req, res, next) => {
  try {
    const input = validate(verifyShopSchema, req.body);
    const shop = await prisma.shop.update({
      where: { id: String(req.params.id) },
      data: {
        verified: input.verified,
        verificationNote: input.verificationNote,
        status: input.verified ? 'ACTIVE' : 'SUSPENDED',
      },
    });
    res.json({ shop });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/follow', async (req, res, next) => {
  try {
    const input = validate(followStoreSchema, req.body);
    const shopId = String(req.params.id);
    const email = input.email.toLowerCase();
    const user = await prisma.user.upsert({
      where: { email },
      update: { name: input.name },
      create: { email, name: input.name, role: 'CUSTOMER' },
    });
    const [follow, loyalty] = await prisma.$transaction([
      prisma.storeFollow.upsert({
        where: { userId_shopId: { userId: user.id, shopId } },
        update: {},
        create: { userId: user.id, shopId },
      }),
      prisma.loyaltyAccount.upsert({
        where: { userId_shopId: { userId: user.id, shopId } },
        update: {},
        create: {
          userId: user.id,
          shopId,
          points: 25,
          referralCode: `${user.id.slice(-5).toUpperCase()}${shopId.slice(-3).toUpperCase()}`,
        },
      }),
    ]);
    res.status(201).json({ follow, loyalty });
  } catch (error) {
    next(error);
  }
});

app.delete('/api/shops/:id/follow', async (req, res, next) => {
  try {
    const input = validate(followStoreSchema, req.body);
    const shopId = String(req.params.id);
    const email = input.email.toLowerCase();
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.json({ unfollowed: false });
    }
    await prisma.storeFollow.deleteMany({
      where: { userId: user.id, shopId },
    });
    res.json({ unfollowed: true });
  } catch (error) {
    next(error);
  }
});

app.get('/api/customers/:email/follows', async (req, res, next) => {
  try {
    const email = String(req.params.email).toLowerCase();
    const follows = await prisma.storeFollow.findMany({
      where: { user: { email } },
      include: { shop: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ follows });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/analytics', async (req, res, next) => {
  try {
    const input = validate(analyticsEventSchema, req.body);
    const shopId = String(req.params.id);
    const day = new Date();
    day.setHours(0, 0, 0, 0);
    const increments = {
      view: { views: { increment: 1 } },
      click: { clicks: { increment: 1 } },
      addToCart: { addToCarts: { increment: 1 } },
      order: { orders: { increment: 1 }, revenue: { increment: input.revenue ?? 0 } },
    }[input.event];
    const analytics = await prisma.storeAnalyticsDaily.upsert({
      where: { shopId_day: { shopId, day } },
      update: {
        ...increments,
        topCity: input.topCity,
        bestProductId: input.bestProductId,
      },
      create: {
        shopId,
        day,
        views: input.event === 'view' ? 1 : 0,
        clicks: input.event === 'click' ? 1 : 0,
        addToCarts: input.event === 'addToCart' ? 1 : 0,
        orders: input.event === 'order' ? 1 : 0,
        revenue: input.event === 'order' ? input.revenue ?? 0 : 0,
        topCity: input.topCity,
        bestProductId: input.bestProductId,
      },
    });
    res.status(201).json({ analytics });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/campaigns', async (req, res, next) => {
  try {
    const input = validate(createCampaignSchema, req.body);
    const campaign = await prisma.notificationCampaign.create({
      data: { ...input, shopId: String(req.params.id) },
    });
    if (campaign.channel === 'PUSH' && !campaign.scheduledAt) {
      const delivery = await sendCampaignPush(campaign);
      return res.status(201).json({ campaign: delivery.campaign, delivery });
    }
    res.status(201).json({ campaign, delivery: null });
  } catch (error) {
    next(error);
  }
});

app.post('/api/devices/register', async (req, res, next) => {
  try {
    const input = validate(registerDeviceTokenSchema, req.body);
    const user = await prisma.user.findUnique({
      where: { email: input.email.toLowerCase() },
    });
    if (!user) {
      const error = new Error('User not found for device token');
      error.status = 404;
      throw error;
    }
    const device = await prisma.deviceToken.upsert({
      where: { token: input.token },
      update: {
        userId: user.id,
        platform: input.platform,
        enabled: true,
        lastSeenAt: new Date(),
      },
      create: {
        userId: user.id,
        token: input.token,
        platform: input.platform,
      },
    });
    res.status(201).json({ device });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shops/:id/placements', async (req, res, next) => {
  try {
    const input = validate(createPlacementSchema, req.body);
    const placement = await prisma.sponsoredPlacement.create({
      data: { ...input, shopId: String(req.params.id) },
    });
    res.status(201).json({ placement });
  } catch (error) {
    next(error);
  }
});

app.get('/api/shops/:id/inventory', async (req, res, next) => {
  try {
    const shopId = String(req.params.id);
    const [products, collections] = await Promise.all([
      prisma.product.findMany({
        where: { shopId, active: true },
        orderBy: { updatedAt: 'desc' },
        include: {
          images: { orderBy: { position: 'asc' } },
          variants: { orderBy: { title: 'asc' } },
          collections: {
            include: { collection: true },
          },
        },
      }),
      prisma.collection.findMany({
        where: { shopId },
        orderBy: { title: 'asc' },
        include: {
          _count: {
            select: { products: true },
          },
        },
      }),
    ]);

    res.json({ products, collections });
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
        shop: { status: 'ACTIVE', verified: true },
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
      include: {
        shop: true,
        images: { orderBy: { position: 'asc' } },
        variants: { orderBy: { title: 'asc' } },
        collections: {
          include: { collection: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ products });
  } catch (error) {
    next(error);
  }
});

app.patch('/api/products/:id/featured', async (req, res, next) => {
  try {
    const product = await prisma.product.findUnique({ where: { id: req.params.id } });
    if (!product) {
      const error = new Error('Product not found');
      error.status = 404;
      throw error;
    }
    const featured = Boolean(req.body?.featured);
    if (featured && !product.featured) {
      const count = await prisma.product.count({
        where: { shopId: product.shopId, featured: true },
      });
      if (count >= 10) {
        const error = new Error('A store can feature up to 10 products');
        error.status = 409;
        throw error;
      }
    }
    const updated = await prisma.product.update({
      where: { id: product.id },
      data: { featured },
      include: {
        shop: true,
        images: { orderBy: { position: 'asc' } },
        variants: { orderBy: { title: 'asc' } },
        collections: { include: { collection: true } },
      },
    });
    res.json({ product: updated });
  } catch (error) {
    next(error);
  }
});

app.post('/api/products/:id/favorite', async (req, res, next) => {
  try {
    const input = validate(favoriteProductSchema, req.body);
    const user = await prisma.user.upsert({
      where: { email: input.customerEmail },
      update: { name: input.customerName },
      create: {
        email: input.customerEmail,
        name: input.customerName,
        role: 'CUSTOMER',
      },
    });
    const favorite = await prisma.favorite.upsert({
      where: { userId_productId: { userId: user.id, productId: req.params.id } },
      update: {},
      create: { userId: user.id, productId: req.params.id },
    });
    res.status(201).json({ favorite });
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
        compareAtPrice: input.compareAtPrice,
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
    if (!input.shopDomain) {
      const error = new Error('Shopify store URL is required');
      error.status = 400;
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
    const tokenBody = await exchangeShopifyToken(shopDomain, {
      client_id: process.env.SHOPIFY_API_KEY,
      client_secret: process.env.SHOPIFY_API_SECRET,
      code,
      expiring: 1,
    });
    const tokenData = shopifyTokenData(tokenBody);
    await prisma.shopifyConnection.upsert({
      where: { shopId: stateData.shopId },
      update: {
        shopDomain,
        ...tokenData,
        apiVersion: process.env.SHOPIFY_API_VERSION || '2026-01',
      },
      create: {
        shopId: stateData.shopId,
        shopDomain,
        ...tokenData,
        apiVersion: process.env.SHOPIFY_API_VERSION || '2026-01',
      },
    });
    const deepLink = `souklora://shopify-connected?shopId=${encodeURIComponent(stateData.shopId)}`;
    res.type('html').send(`<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Shopify connected</title>
    <script>
      window.location.href = "${deepLink}";
    </script>
    <style>
      body { font-family: system-ui, sans-serif; padding: 24px; line-height: 1.4; }
      a { display: inline-block; margin-top: 16px; }
    </style>
  </head>
  <body>
    <h1>Shopify connected</h1>
    <p>You can return to Souklora and sync products.</p>
    <a href="${deepLink}">Open Souklora</a>
  </body>
</html>`);
  } catch (error) {
    next(error);
  }
});

app.get('/api/shopify/status', async (req, res, next) => {
  try {
    const { shopId } = req.query;
    if (!shopId) {
      const error = new Error('shopId is required');
      error.status = 400;
      throw error;
    }
    const connection = await prisma.shopifyConnection.findUnique({
      where: { shopId: String(shopId) },
      select: {
        shopDomain: true,
        refreshToken: true,
        scopes: true,
        lastSyncedAt: true,
        updatedAt: true,
      },
    });
    const needsReconnect = Boolean(connection && !connection.refreshToken);
    res.json({
      connected: Boolean(connection) && !needsReconnect,
      needsReconnect,
      shopDomain: connection?.shopDomain ?? null,
      lastSyncedAt: connection?.lastSyncedAt ?? null,
      connectedAt: connection?.updatedAt ?? null,
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/shopify/sync', async (req, res, next) => {
  try {
    const input = validate(syncShopifySchema, req.body);
    const shop = await prisma.shop.findUnique({
      where: { id: input.shopId },
      select: { status: true, verified: true },
    });
    if (!shop || shop.status !== 'ACTIVE' || !shop.verified) {
      const error = new Error('Store must be approved by Scalora admin before Shopify sync');
      error.status = 403;
      throw error;
    }
    const existingJob = [...shopifySyncJobs.values()].find(
      (job) => job.shopId === input.shopId && (job.status === 'queued' || job.status === 'running'),
    );
    if (existingJob) {
      return res.status(202).json({ jobId: existingJob.id, status: existingJob.status });
    }

    const job = {
      id: crypto.randomUUID(),
      shopId: input.shopId,
      status: 'queued',
      progress: 2,
      message: 'Queued Shopify sync',
      result: null,
      error: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    shopifySyncJobs.set(job.id, job);
    runShopifySyncJob(job.id);
    res.status(202).json({ jobId: job.id, status: job.status, progress: job.progress, message: job.message });
  } catch (error) {
    next(error);
  }
});

app.get('/api/shopify/sync/:jobId', (req, res) => {
  const job = shopifySyncJobs.get(req.params.jobId);
  if (!job) {
    return res.status(404).json({ error: 'Sync job not found' });
  }
  res.json(job);
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

    const shopifyUpdates = await syncSoukloraOrderToShopifyInventory(input.shopId, order.items);
    const day = new Date();
    day.setHours(0, 0, 0, 0);
    await prisma.$transaction([
      prisma.shop.update({
        where: { id: input.shopId },
        data: { orderCount: { increment: 1 } },
      }),
      prisma.storeAnalyticsDaily.upsert({
        where: { shopId_day: { shopId: input.shopId, day } },
        update: {
          orders: { increment: 1 },
          revenue: { increment: total },
        },
        create: {
          shopId: input.shopId,
          day,
          orders: 1,
          revenue: total,
        },
      }),
    ]);
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

app.post('/api/shops/:id/reviews', async (req, res, next) => {
  try {
    const input = validate(createReviewSchema, req.body);
    const shopId = String(req.params.id);
    const user = await prisma.user.upsert({
      where: { email: input.customerEmail },
      update: { name: input.customerName },
      create: {
        email: input.customerEmail,
        name: input.customerName,
        role: 'CUSTOMER',
      },
    });
    const review = await prisma.review.create({
      data: {
        userId: user.id,
        shopId,
        rating: input.rating,
        comment: input.comment,
      },
    });
    const aggregate = await prisma.review.aggregate({
      where: { shopId },
      _avg: { rating: true },
    });
    await prisma.shop.update({
      where: { id: shopId },
      data: { rating: aggregate._avg.rating ?? input.rating },
    });
    res.status(201).json({ review });
  } catch (error) {
    next(error);
  }
});

app.get('/api/shops/:id/reviews', async (req, res, next) => {
  try {
    const reviews = await prisma.review.findMany({
      where: { shopId: String(req.params.id) },
      include: { user: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json({ reviews });
  } catch (error) {
    next(error);
  }
});

app.post('/api/ai/product-copy', (req, res, next) => {
  try {
    const input = validate(aiProductCopySchema, req.body);
    const keywords = input.keywords ? ` Designed around ${input.keywords}.` : '';
    res.json({
      description:
        `${input.productName} brings a ${input.tone} feel to ${input.category}.` +
        `${keywords} Easy to style, simple to order, and ready for local delivery through Souklora.`,
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/ai/ad-copy', (req, res, next) => {
  try {
    const input = validate(aiAdCopySchema, req.body);
    const prefix = input.channel === 'whatsapp' ? 'Hi! ' : '';
    res.json({
      caption: `${prefix}${input.storeName} just launched: ${input.offer}. Shop now on Souklora before it is gone.`,
      headline: `${input.offer} at ${input.storeName}`,
    });
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

function updateShopifySyncJob(jobId, patch) {
  const job = shopifySyncJobs.get(jobId);
  if (!job) {
    return null;
  }
  Object.assign(job, patch, { updatedAt: new Date() });
  return job;
}

async function runShopifySyncJob(jobId) {
  const job = shopifySyncJobs.get(jobId);
  if (!job) {
    return;
  }
  try {
    updateShopifySyncJob(jobId, {
      status: 'running',
      progress: 8,
      message: 'Checking Shopify connection',
    });
    const connection = await prisma.shopifyConnection.findUnique({
      where: { shopId: job.shopId },
    });
    if (!connection) {
      const error = new Error('Shopify is not connected for this shop');
      error.status = 404;
      throw error;
    }

    const freshConnection = await refreshShopifyConnection(connection);
    updateShopifySyncJob(jobId, {
      progress: 18,
      message: 'Downloading products, collections, variants, and images from Shopify',
    });
    const catalog = await fetchShopifyCatalog(freshConnection, (progress) => {
      updateShopifySyncJob(jobId, progress);
    });
    updateShopifySyncJob(jobId, {
      progress: 72,
      message: 'Saving Shopify catalog into Souklora',
    });
    const result = await upsertShopifyCatalog(job.shopId, freshConnection, catalog, (progress) => {
      updateShopifySyncJob(jobId, progress);
    });
    updateShopifySyncJob(jobId, {
      status: 'completed',
      progress: 100,
      message: `Synced ${result.products} products and ${result.collections} collections`,
      result,
    });
  } catch (error) {
    updateShopifySyncJob(jobId, {
      status: 'failed',
      progress: 100,
      message: error.message || 'Shopify sync failed',
      error: error.details ?? null,
    });
  }
}

async function upsertShopifyCatalog(shopId, connection, catalog, onProgress = () => {}) {
  const now = new Date();
  const inventoryByItemId = new Map(
    catalog.inventoryLevels.map((level) => [String(level.inventory_item_id), level]),
  );
  const productByShopifyId = new Map();

  for (let index = 0; index < catalog.collections.length; index += 1) {
    const collection = catalog.collections[index];
    if (index % 25 === 0) {
      onProgress({
        progress: Math.min(78, 72 + Math.round((index / Math.max(catalog.collections.length, 1)) * 6)),
        message: `Saving collections ${index + 1}/${catalog.collections.length}`,
      });
    }
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

  for (let index = 0; index < catalog.products.length; index += 1) {
    const shopifyProduct = catalog.products[index];
    if (index % 25 === 0) {
      onProgress({
        progress: Math.min(94, 78 + Math.round((index / Math.max(catalog.products.length, 1)) * 16)),
        message: `Saving products ${index + 1}/${catalog.products.length}`,
      });
    }
    const variant = shopifyProduct.variants?.[0];
    if (!variant) {
      continue;
    }
    if (shopifyProduct.status === 'archived') {
      await prisma.product.updateMany({
        where: { shopId, shopifyProductId: String(shopifyProduct.id) },
        data: { active: false, lastSyncedAt: now },
      });
      continue;
    }
    const variantRows = (shopifyProduct.variants ?? []).map((currentVariant) => {
      const variantInventoryLevel = inventoryByItemId.get(String(currentVariant.inventory_item_id));
      return {
        id: crypto.randomUUID(),
        title: currentVariant.title || 'Default',
        price: Number(currentVariant.price ?? 0),
        compareAtPrice: currentVariant.compare_at_price ? Number(currentVariant.compare_at_price) : null,
        stock: Number(variantInventoryLevel?.available ?? currentVariant.inventory_quantity ?? 0),
        sku: currentVariant.sku || null,
        option1: currentVariant.option1 || null,
        option2: currentVariant.option2 || null,
        option3: currentVariant.option3 || null,
        shopifyVariantId: String(currentVariant.id),
        shopifyInventoryItemId: String(currentVariant.inventory_item_id),
      };
    });
    const productStock = variantRows.reduce((sum, currentVariant) => sum + currentVariant.stock, 0);
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
        compareAtPrice: variant.compare_at_price ? Number(variant.compare_at_price) : null,
        stock: productStock,
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
        compareAtPrice: variant.compare_at_price ? Number(variant.compare_at_price) : null,
        stock: productStock,
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

    await prisma.productImage.deleteMany({ where: { productId: product.id } });
    const imageRows = (shopifyProduct.images ?? [])
      .filter((image) => image.src)
      .map((image, index) => ({
        id: crypto.randomUUID(),
        productId: product.id,
        url: image.src,
        altText: image.alt ?? null,
        position: Number(image.position ?? index),
      }));
    if (imageRows.length > 0) {
      await prisma.productImage.createMany({
        data: imageRows,
        skipDuplicates: true,
      });
    }

    await prisma.productVariant.deleteMany({ where: { productId: product.id } });
    if (variantRows.length > 0) {
      await prisma.productVariant.createMany({
        data: variantRows.map((currentVariant) => ({
          ...currentVariant,
          productId: product.id,
        })),
        skipDuplicates: true,
      });
    }
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
  if (catalog.menu) {
    await prisma.shop.update({
      where: { id: shopId },
      data: { shopifyMenu: catalog.menu },
    });
  }

  return {
    syncedAt: now,
    products: productByShopifyId.size,
    collections: catalog.collections.length,
  };
}

async function sendCampaignPush(campaign) {
  const follows = await prisma.storeFollow.findMany({
    where: { shopId: campaign.shopId },
    include: {
      user: {
        include: {
          deviceTokens: {
            where: { enabled: true },
          },
        },
      },
    },
  });
  const tokens = [
    ...new Set(
      follows.flatMap((follow) =>
        follow.user.deviceTokens.map((device) => device.token),
      ),
    ),
  ];
  const result = await sendPushToTokens({
    tokens,
    title: campaign.title,
    body: campaign.message,
    data: {
      type: 'campaign',
      campaignId: campaign.id,
      shopId: campaign.shopId,
    },
  });
  if (result.invalidTokens.length > 0) {
    await prisma.deviceToken.updateMany({
      where: { token: { in: result.invalidTokens } },
      data: { enabled: false },
    });
  }
  const updatedCampaign = await prisma.notificationCampaign.update({
    where: { id: campaign.id },
    data: {
      sentAt: new Date(),
      deliveredCount: result.delivered,
      failedCount: result.failed,
    },
  });
  return {
    campaign: updatedCampaign,
    followerCount: follows.length,
    deviceCount: tokens.length,
    delivered: result.delivered,
    failed: result.failed,
  };
}

function stripHtml(value) {
  return value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

async function syncSoukloraOrderToShopifyInventory(shopId, orderItems) {
  const connection = await prisma.shopifyConnection.findUnique({ where: { shopId } });
  if (!connection) {
    return { updated: [], failed: [] };
  }

  let freshConnection;
  try {
    freshConnection = await refreshShopifyConnection(connection);
  } catch (error) {
    return { updated: [], failed: [{ shopId, reason: error.message }] };
  }

  const updated = [];
  const failed = [];
  for (const item of orderItems) {
    const product = item.product;
    if (!product.shopifyInventoryItemId) {
      continue;
    }
    const locationId = product.shopifyLocationId || freshConnection.defaultLocationId;
    if (!locationId) {
      failed.push({ productId: product.id, reason: 'Missing Shopify location id' });
      continue;
    }
    try {
      const result = await adjustShopifyInventory({
        connection: freshConnection,
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
  console.log(`Souklora API listening on port ${port}`);
});
