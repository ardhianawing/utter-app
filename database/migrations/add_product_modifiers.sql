-- ============================================================
-- MIGRATION: Add Product Type & Modifiers Support
-- Deskripsi: Menambahkan fitur tipe produk (Ramen/Drink) dan 
--            sistem modifier (topping, kuah, sugar level, dll)
-- Tanggal: 2026-01-31
-- ============================================================

-- ============================================================
-- STEP 1: Tambah Kolom 'type' ke Tabel 'products'
-- ============================================================
-- Kolom ini untuk membedakan produk Standard, Ramen, atau Drink
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'STANDARD';

-- Update semua produk existing menjadi STANDARD
UPDATE products 
SET type = 'STANDARD' 
WHERE type IS NULL;

COMMENT ON COLUMN products.type IS 'Tipe produk: STANDARD, RAMEN, atau DRINK';


-- ============================================================
-- STEP 2: Buat Tabel 'product_modifiers'
-- ============================================================
-- Tabel ini menyimpan pilihan topping, kuah, sugar level, dll
CREATE TABLE IF NOT EXISTS product_modifiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    extra_price DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE product_modifiers IS 'Menyimpan modifier/topping untuk produk (Ramen, Drink, dll)';
COMMENT ON COLUMN product_modifiers.category IS 'Kategori modifier: Topping, Broth, Sugar Level, Ice Level, dll';
COMMENT ON COLUMN product_modifiers.name IS 'Nama modifier: Extra Chashu, Tori Paitan, Less Sugar, dll';
COMMENT ON COLUMN product_modifiers.extra_price IS 'Harga tambahan untuk modifier ini (bisa 0)';


-- ============================================================
-- STEP 3: Enable Row Level Security (RLS)
-- ============================================================
ALTER TABLE product_modifiers ENABLE ROW LEVEL SECURITY;

-- Hapus policy jika sudah ada agar tidak error saat running ulang
DROP POLICY IF EXISTS "Enable read access for all users" ON product_modifiers;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON product_modifiers;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON product_modifiers;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON product_modifiers;

-- Buat balik policy
CREATE POLICY "Enable read access for all users" ON product_modifiers FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON product_modifiers FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON product_modifiers FOR UPDATE USING (true);
CREATE POLICY "Enable delete for authenticated users" ON product_modifiers FOR DELETE USING (true);


-- ============================================================
-- STEP 4: Buat Index untuk Performa
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_product_modifiers_product_id 
ON product_modifiers(product_id);

CREATE INDEX IF NOT EXISTS idx_product_modifiers_category 
ON product_modifiers(category);


-- ============================================================
-- STEP 5: Tambah Kolom 'selected_modifiers' ke 'order_items'
-- ============================================================
-- Kolom ini menyimpan pilihan modifier yang dipilih customer
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS selected_modifiers JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN order_items.selected_modifiers IS 'Menyimpan modifier yang dipilih customer dalam format JSON';


-- ============================================================
-- STEP 6: Update Product Types & Add Sample Data (Idempotent)
-- ============================================================

-- 1. Set Product Types based on Names (Lebih aman daripada ID hardcoded)
UPDATE products SET type = 'RAMEN' WHERE name ILIKE '%Ramen%';
UPDATE products SET type = 'DRINK' WHERE category IN ('BEVERAGE_COFFEE', 'BEVERAGE_NON_COFFEE');

-- 2. Tambahkan modifier untuk Katsu Ramen
DO $$ 
DECLARE 
    v_katsu_id UUID;
    v_tori_id UUID;
    v_milko_id UUID;
BEGIN
    -- Ambil ID berdasarkan nama
    SELECT id INTO v_katsu_id FROM products WHERE name = 'Katsu Ramen' LIMIT 1;
    SELECT id INTO v_tori_id FROM products WHERE name = 'Tori Paitan Ramen' LIMIT 1;
    SELECT id INTO v_milko_id FROM products WHERE name = 'Milko Caramel' LIMIT 1;

    -- Bersihkan data lama untuk ID yang ditemukan
    IF v_katsu_id IS NOT NULL THEN
        DELETE FROM product_modifiers WHERE product_id = v_katsu_id;
        INSERT INTO product_modifiers (product_id, category, name, extra_price) VALUES
        (v_katsu_id, 'Topping', 'Ajitsuke Tamago (Telur)', 5000),
        (v_katsu_id, 'Topping', 'Extra Chashu', 10000),
        (v_katsu_id, 'Topping', 'Extra Nori', 3000),
        (v_katsu_id, 'Broth', 'Tori Paitan (Original)', 0),
        (v_katsu_id, 'Broth', 'Spicy Miso', 5000),
        (v_katsu_id, 'Broth', 'Shoyu', 0);
    END IF;

    IF v_tori_id IS NOT NULL THEN
        DELETE FROM product_modifiers WHERE product_id = v_tori_id;
        INSERT INTO product_modifiers (product_id, category, name, extra_price) VALUES
        (v_tori_id, 'Topping', 'Extra Chicken', 8000),
        (v_tori_id, 'Topping', 'Prawn (Udang)', 12000),
        (v_tori_id, 'Broth', 'Creamy Chicken', 0),
        (v_tori_id, 'Broth', 'Curry Broth', 5000);
    END IF;

    IF v_milko_id IS NOT NULL THEN
        DELETE FROM product_modifiers WHERE product_id = v_milko_id;
        INSERT INTO product_modifiers (product_id, category, name, extra_price) VALUES
        (v_milko_id, 'Sugar', 'Normal Sugar', 0),
        (v_milko_id, 'Sugar', 'Less Sugar', 0),
        (v_milko_id, 'Ice', 'Normal Ice', 0),
        (v_milko_id, 'Ice', 'Less Ice', 0),
        (v_milko_id, 'Topping', 'Boba', 5000),
        (v_milko_id, 'Topping', 'Grass Jelly', 3000);
    END IF;
END $$;


-- ============================================================
-- VERIFICATION QUERIES (Untuk Cek Hasil)
-- ============================================================
-- Jalankan query ini setelah migration untuk memastikan berhasil:

-- 1. Cek kolom 'type' sudah ada di tabel products
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'products' AND column_name = 'type';

-- 2. Cek tabel product_modifiers sudah dibuat
-- SELECT * FROM product_modifiers LIMIT 5;

-- 3. Cek kolom selected_modifiers sudah ada di order_items
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'order_items' AND column_name = 'selected_modifiers';


-- ============================================================
-- SELESAI! 
-- ============================================================
-- Aplikasi sekarang siap untuk:
-- ✅ Menampilkan pilihan Product Type (Standard/Ramen/Drink)
-- ✅ Menambahkan Topping/Kuah untuk produk Ramen
-- ✅ Menyimpan pilihan customer saat order
-- ============================================================
