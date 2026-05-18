CREATE TYPE "SubscriptionPlan" AS ENUM ('FREE', 'BASIC', 'PRO', 'ENTERPRISE');
CREATE TYPE "PlacementStatus" AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ENDED');
CREATE TYPE "CampaignChannel" AS ENUM ('PUSH', 'WHATSAPP', 'EMAIL');

ALTER TABLE "Shop" ADD COLUMN "logoUrl" TEXT;
ALTER TABLE "Shop" ADD COLUMN "bannerUrl" TEXT;
ALTER TABLE "Shop" ADD COLUMN "primaryColor" TEXT;
ALTER TABLE "Shop" ADD COLUMN "accentColor" TEXT;
ALTER TABLE "Shop" ADD COLUMN "instagramUrl" TEXT;
ALTER TABLE "Shop" ADD COLUMN "tiktokUrl" TEXT;
ALTER TABLE "Shop" ADD COLUMN "websiteUrl" TEXT;
ALTER TABLE "Shop" ADD COLUMN "whatsappPhone" TEXT;
ALTER TABLE "Shop" ADD COLUMN "contactEmail" TEXT;
ALTER TABLE "Shop" ADD COLUMN "shippingPolicy" TEXT;
ALTER TABLE "Shop" ADD COLUMN "returnPolicy" TEXT;
ALTER TABLE "Shop" ADD COLUMN "verified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Shop" ADD COLUMN "verificationNote" TEXT;
ALTER TABLE "Shop" ADD COLUMN "subscriptionPlan" "SubscriptionPlan" NOT NULL DEFAULT 'FREE';

CREATE TABLE "StoreFollow" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "StoreFollow_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LoyaltyAccount" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "points" INTEGER NOT NULL DEFAULT 0,
  "tier" TEXT NOT NULL DEFAULT 'Member',
  "referralCode" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LoyaltyAccount_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "NotificationCampaign" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "channel" "CampaignChannel" NOT NULL DEFAULT 'PUSH',
  "title" TEXT NOT NULL,
  "message" TEXT NOT NULL,
  "audience" TEXT NOT NULL DEFAULT 'followers',
  "scheduledAt" TIMESTAMP(3),
  "sentAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "NotificationCampaign_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SponsoredPlacement" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "productId" TEXT,
  "title" TEXT NOT NULL,
  "placement" TEXT NOT NULL DEFAULT 'home',
  "budget" DECIMAL(65,30) NOT NULL DEFAULT 0,
  "status" "PlacementStatus" NOT NULL DEFAULT 'DRAFT',
  "startsAt" TIMESTAMP(3),
  "endsAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SponsoredPlacement_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "StoreAnalyticsDaily" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "day" TIMESTAMP(3) NOT NULL,
  "views" INTEGER NOT NULL DEFAULT 0,
  "clicks" INTEGER NOT NULL DEFAULT 0,
  "addToCarts" INTEGER NOT NULL DEFAULT 0,
  "orders" INTEGER NOT NULL DEFAULT 0,
  "revenue" DECIMAL(65,30) NOT NULL DEFAULT 0,
  "bestProductId" TEXT,
  "topCity" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "StoreAnalyticsDaily_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "StoreFollow_userId_shopId_key" ON "StoreFollow"("userId", "shopId");
CREATE INDEX "StoreFollow_shopId_idx" ON "StoreFollow"("shopId");
CREATE UNIQUE INDEX "LoyaltyAccount_userId_shopId_key" ON "LoyaltyAccount"("userId", "shopId");
CREATE INDEX "SponsoredPlacement_status_placement_idx" ON "SponsoredPlacement"("status", "placement");
CREATE UNIQUE INDEX "StoreAnalyticsDaily_shopId_day_key" ON "StoreAnalyticsDaily"("shopId", "day");

ALTER TABLE "StoreFollow" ADD CONSTRAINT "StoreFollow_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StoreFollow" ADD CONSTRAINT "StoreFollow_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LoyaltyAccount" ADD CONSTRAINT "LoyaltyAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LoyaltyAccount" ADD CONSTRAINT "LoyaltyAccount_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "NotificationCampaign" ADD CONSTRAINT "NotificationCampaign_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SponsoredPlacement" ADD CONSTRAINT "SponsoredPlacement_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SponsoredPlacement" ADD CONSTRAINT "SponsoredPlacement_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "StoreAnalyticsDaily" ADD CONSTRAINT "StoreAnalyticsDaily_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
