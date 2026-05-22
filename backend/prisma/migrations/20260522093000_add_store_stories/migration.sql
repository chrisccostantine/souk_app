CREATE TABLE "StoreStory" (
    "id" TEXT NOT NULL,
    "shopId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "caption" TEXT,
    "imageUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StoreStory_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "StoreStory_expiresAt_idx" ON "StoreStory"("expiresAt");
CREATE INDEX "StoreStory_shopId_createdAt_idx" ON "StoreStory"("shopId", "createdAt");

ALTER TABLE "StoreStory" ADD CONSTRAINT "StoreStory_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
