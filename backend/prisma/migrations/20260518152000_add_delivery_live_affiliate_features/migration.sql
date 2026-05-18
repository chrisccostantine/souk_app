CREATE TYPE "CollaborationStatus" AS ENUM ('PROPOSED', 'ACTIVE', 'COMPLETED', 'CANCELLED');

CREATE TABLE "DeliveryRegion" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "fee" DECIMAL(65,30) NOT NULL DEFAULT 0,
  "eta" TEXT NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "DeliveryRegion_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LiveSellingEvent" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "startsAt" TIMESTAMP(3) NOT NULL,
  "streamUrl" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "LiveSellingEvent_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AffiliateLink" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "creatorName" TEXT NOT NULL,
  "creatorHandle" TEXT,
  "code" TEXT NOT NULL,
  "commissionRate" DECIMAL(65,30) NOT NULL DEFAULT 0,
  "status" "CollaborationStatus" NOT NULL DEFAULT 'PROPOSED',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AffiliateLink_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AffiliateLink_shopId_code_key" ON "AffiliateLink"("shopId", "code");

ALTER TABLE "DeliveryRegion" ADD CONSTRAINT "DeliveryRegion_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LiveSellingEvent" ADD CONSTRAINT "LiveSellingEvent_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AffiliateLink" ADD CONSTRAINT "AffiliateLink_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
