-- ============================================================
-- DANGER: RESET TRANSACTION DATA
-- Description: Deletes all sales history, shifts, and orders.
--              Keeps Order Master Data (Products, Tables, Staff/Profiles).
-- ============================================================

-- 1. Truncate tables (CASCADE ensures child tables are cleared too)
--    We use TRUNCATE for speed and complete cleanup.
--    RESTART IDENTITY resets any auto-increment counters (if any).

TRUNCATE TABLE order_items CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE shifts CASCADE;

-- Optional: If you track stock changes in a separate log table
-- TRUNCATE TABLE inventory_logs CASCADE; 

-- Data Verification
SELECT count(*) as total_orders FROM orders;
SELECT count(*) as total_shifts FROM shifts;

-- ============================================================
-- YOUR APP IS NOW FRESH (No Transactions)
-- ============================================================
