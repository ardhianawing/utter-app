-- ============================================================
-- ROLLBACK: Hapus Product Type & Modifiers Support
-- Deskripsi: Mengembalikan database ke kondisi semula
--            (sistem lama yang lebih simple)
-- Tanggal: 2026-01-31
-- ============================================================

-- ============================================================
-- STEP 1: Hapus Kolom 'selected_modifiers' dari 'order_items'
-- ============================================================
ALTER TABLE order_items 
DROP COLUMN IF EXISTS selected_modifiers;


-- ============================================================
-- STEP 2: Hapus Tabel 'product_modifiers'
-- ============================================================
DROP TABLE IF EXISTS product_modifiers CASCADE;


-- ============================================================
-- STEP 3: Hapus Kolom 'type' dari 'products'
-- ============================================================
ALTER TABLE products 
DROP COLUMN IF EXISTS type;


-- ============================================================
-- SELESAI! Database sudah kembali ke sistem lama
-- ============================================================
-- Sekarang Anda bisa setup menu seperti biasa:
-- - Miso Ramen (Rp 10.000)
-- - Katsu Ramen (Rp 18.000)
-- - Tori Ramen (Rp 18.000)
-- - Beef Ramen (Rp 18.000)
-- 
-- Tidak ada pilihan kuah, tidak ada modifier.
-- Simple dan tidak rawan miss!
-- ============================================================
