-- ============================================================
-- MIGRATION: Allow Zero Price/Subtotal for Online Orders
-- Reason: Online orders are tracked with 0 price in order_items
--         to prevent double counting revenue (revenue is entry manually).
-- Author: Antigravity AI
-- Date: 2026-01-31
-- ============================================================

-- 1. Drop existing constraints that force value > 0
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS chk_subtotal_positive;
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS chk_unit_price_positive;

-- 2. Add new constraints that force value >= 0 (allow zero)
ALTER TABLE order_items ADD CONSTRAINT chk_subtotal_non_negative CHECK (subtotal >= 0);
ALTER TABLE order_items ADD CONSTRAINT chk_unit_price_non_negative CHECK (unit_price >= 0);

-- 3. Verify changes (optional comment)
-- If successful, you should be able to insert items with 0 price.
