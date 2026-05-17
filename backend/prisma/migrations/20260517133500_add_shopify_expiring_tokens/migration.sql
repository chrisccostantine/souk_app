ALTER TABLE "ShopifyConnection" ADD COLUMN "refreshToken" TEXT;
ALTER TABLE "ShopifyConnection" ADD COLUMN "accessTokenExpiresAt" TIMESTAMP(3);
ALTER TABLE "ShopifyConnection" ADD COLUMN "refreshTokenExpiresAt" TIMESTAMP(3);
ALTER TABLE "ShopifyConnection" ADD COLUMN "scopes" TEXT;
