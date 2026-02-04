-- ============================================================
-- MIGRATION: Allow Zero Subtotal in Order Items
-- Description: Modifying constraint to allow subtotal >= 0 instead of > 0
--              Required for tracking Online Food items with 0 price
-- Date: 2026-01-31
-- ============================================================

-- Step 1: Drop the existing constraint
ALTER TABLE order_items 
DROP CONSTRAINT IF EXISTS chk_subtotal_positive;

-- Step 2: Add new constraint allowing 0 (subtotal >= 0)
ALTER TABLE order_items 
ADD CONSTRAINT chk_subtotal_non_negative 
CHECK (subtotal >= 0);

-- Note: We also need to check if unit_price has similar constraint
ALTER TABLE order_items 
DROP CONSTRAINT IF EXISTS chk_unit_price_positive;

ALTER TABLE order_items 
ADD CONSTRAINT chk_unit_price_non_negative 
CHECK (unit_price >= 0);
