ALTER TYPE "OrderStatus" ADD VALUE IF NOT EXISTS 'PENDING_SYNC';

ALTER TABLE "Order"
  ADD COLUMN "shopifyOrderId" TEXT,
  ADD COLUMN "idempotencyKey" TEXT,
  ADD COLUMN "discount" DECIMAL(65,30) NOT NULL DEFAULT 0,
  ADD COLUMN "currency" TEXT NOT NULL DEFAULT 'USD',
  ADD COLUMN "customerName" TEXT,
  ADD COLUMN "customerPhone" TEXT,
  ADD COLUMN "customerEmail" TEXT,
  ADD COLUMN "whatsappPhone" TEXT,
  ADD COLUMN "city" TEXT,
  ADD COLUMN "shopifySyncError" TEXT;

CREATE UNIQUE INDEX "Order_idempotencyKey_key" ON "Order"("idempotencyKey");
