-- Storage/Inventory Tables for Utter Ecosystem
-- Migration: 001_storage_tables.sql
-- Description: Create tables for ingredients, product recipes (BOM), and stock movements

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. INGREDIENTS TABLE - Bahan Baku
-- ============================================
CREATE TABLE IF NOT EXISTS ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  unit VARCHAR(50) NOT NULL, -- gram, kg, ml, liter, pcs
  current_stock DECIMAL(10,2) DEFAULT 0,
  cost_per_unit DECIMAL(10,4) DEFAULT 0, -- harga per unit
  min_stock DECIMAL(10,2) DEFAULT 0, -- alert threshold
  supplier_name VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX idx_ingredients_is_active ON ingredients(is_active);
CREATE INDEX idx_ingredients_current_stock ON ingredients(current_stock);

-- ============================================
-- 2. PRODUCT_RECIPES TABLE - Resep/BOM
-- ============================================
CREATE TABLE IF NOT EXISTS product_recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
  quantity DECIMAL(10,3) NOT NULL, -- jumlah yang dipakai per produk
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, ingredient_id)
);

-- Indexes for faster joins
CREATE INDEX idx_product_recipes_product_id ON product_recipes(product_id);
CREATE INDEX idx_product_recipes_ingredient_id ON product_recipes(ingredient_id);

-- ============================================
-- 3. STOCK_MOVEMENTS TABLE - Audit Log
-- ============================================
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  movement_type VARCHAR(50) NOT NULL, -- STOCK_IN, AUTO_DEDUCT, ADJUSTMENT
  quantity DECIMAL(10,3) NOT NULL, -- positive = in, negative = out
  unit_cost DECIMAL(10,4), -- harga per unit saat transaksi
  reference_type VARCHAR(50), -- ORDER, PURCHASE, MANUAL
  reference_id UUID, -- order_id atau purchase_id
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for filtering and reporting
CREATE INDEX idx_stock_movements_ingredient_id ON stock_movements(ingredient_id);
CREATE INDEX idx_stock_movements_movement_type ON stock_movements(movement_type);
CREATE INDEX idx_stock_movements_created_at ON stock_movements(created_at);
CREATE INDEX idx_stock_movements_reference ON stock_movements(reference_type, reference_id);

-- ============================================
-- 4. TRIGGER: Auto-update updated_at for ingredients
-- ============================================
CREATE OR REPLACE FUNCTION update_ingredients_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ingredients_updated_at
  BEFORE UPDATE ON ingredients
  FOR EACH ROW
  EXECUTE FUNCTION update_ingredients_updated_at();

-- ============================================
-- 5. RPC FUNCTION: Deduct Stock
-- ============================================
CREATE OR REPLACE FUNCTION deduct_stock(
  p_ingredient_id UUID,
  p_quantity DECIMAL
)
RETURNS VOID AS $$
BEGIN
  UPDATE ingredients
  SET current_stock = current_stock - p_quantity
  WHERE id = p_ingredient_id;

  -- Prevent negative stock (optional - can be removed if negative is allowed)
  UPDATE ingredients
  SET current_stock = 0
  WHERE id = p_ingredient_id AND current_stock < 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. RPC FUNCTION: Add Stock
-- ============================================
CREATE OR REPLACE FUNCTION add_stock(
  p_ingredient_id UUID,
  p_quantity DECIMAL,
  p_unit_cost DECIMAL DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  -- Update current stock
  UPDATE ingredients
  SET current_stock = current_stock + p_quantity
  WHERE id = p_ingredient_id;

  -- Update cost_per_unit if provided (weighted average could be implemented here)
  IF p_unit_cost IS NOT NULL THEN
    UPDATE ingredients
    SET cost_per_unit = p_unit_cost
    WHERE id = p_ingredient_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. RPC FUNCTION: Get Low Stock Ingredients
-- ============================================
CREATE OR REPLACE FUNCTION get_low_stock_ingredients()
RETURNS TABLE (
  id UUID,
  name VARCHAR(255),
  unit VARCHAR(50),
  current_stock DECIMAL(10,2),
  min_stock DECIMAL(10,2),
  cost_per_unit DECIMAL(10,4),
  supplier_name VARCHAR(255)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.name,
    i.unit,
    i.current_stock,
    i.min_stock,
    i.cost_per_unit,
    i.supplier_name
  FROM ingredients i
  WHERE i.is_active = true
    AND i.current_stock <= i.min_stock
  ORDER BY (i.current_stock / NULLIF(i.min_stock, 0)) ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. RPC FUNCTION: Calculate HPP for Product
-- ============================================
CREATE OR REPLACE FUNCTION calculate_product_hpp(p_product_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  v_hpp DECIMAL(10,2) := 0;
BEGIN
  SELECT COALESCE(SUM(pr.quantity * i.cost_per_unit), 0)
  INTO v_hpp
  FROM product_recipes pr
  JOIN ingredients i ON i.id = pr.ingredient_id
  WHERE pr.product_id = p_product_id;

  RETURN v_hpp;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. VIEW: Product HPP Summary
-- ============================================
CREATE OR REPLACE VIEW product_hpp_summary AS
SELECT
  p.id AS product_id,
  p.name AS product_name,
  p.price AS selling_price,
  COALESCE(SUM(pr.quantity * i.cost_per_unit), 0) AS hpp,
  p.price - COALESCE(SUM(pr.quantity * i.cost_per_unit), 0) AS profit_margin,
  CASE
    WHEN p.price > 0 THEN
      ((p.price - COALESCE(SUM(pr.quantity * i.cost_per_unit), 0)) / p.price * 100)
    ELSE 0
  END AS profit_percent
FROM products p
LEFT JOIN product_recipes pr ON pr.product_id = p.id
LEFT JOIN ingredients i ON i.id = pr.ingredient_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.price;

-- ============================================
-- 10. RPC FUNCTION: Process Order Deduction
-- Auto-deduct ingredients when order is completed
-- ============================================
CREATE OR REPLACE FUNCTION process_order_ingredient_deduction(
  p_order_id UUID,
  p_created_by UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_item RECORD;
  v_recipe RECORD;
  v_deduct_qty DECIMAL;
BEGIN
  -- Loop through order items
  FOR v_item IN
    SELECT oi.product_id, oi.quantity
    FROM order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    -- Loop through product recipes
    FOR v_recipe IN
      SELECT pr.ingredient_id, pr.quantity, i.cost_per_unit
      FROM product_recipes pr
      JOIN ingredients i ON i.id = pr.ingredient_id
      WHERE pr.product_id = v_item.product_id
    LOOP
      v_deduct_qty := v_recipe.quantity * v_item.quantity;

      -- Deduct stock
      PERFORM deduct_stock(v_recipe.ingredient_id, v_deduct_qty);

      -- Log movement
      INSERT INTO stock_movements (
        ingredient_id,
        movement_type,
        quantity,
        unit_cost,
        reference_type,
        reference_id,
        created_by
      ) VALUES (
        v_recipe.ingredient_id,
        'AUTO_DEDUCT',
        -v_deduct_qty,
        v_recipe.cost_per_unit,
        'ORDER',
        p_order_id,
        p_created_by
      );
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 11. RLS Policies (optional - enable if using RLS)
-- ============================================
-- ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE product_recipes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all authenticated users to read
-- CREATE POLICY "Allow read for authenticated" ON ingredients FOR SELECT TO authenticated USING (true);
-- CREATE POLICY "Allow read for authenticated" ON product_recipes FOR SELECT TO authenticated USING (true);
-- CREATE POLICY "Allow read for authenticated" ON stock_movements FOR SELECT TO authenticated USING (true);

-- Policy: Allow admin to insert/update/delete
-- CREATE POLICY "Allow admin full access" ON ingredients FOR ALL TO authenticated USING (
--   EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
-- );

-- ============================================
-- SAMPLE DATA (optional - for testing)
-- ============================================
-- INSERT INTO ingredients (name, unit, current_stock, cost_per_unit, min_stock, supplier_name) VALUES
-- ('Kopi Arabica', 'gram', 5000, 0.5, 1000, 'CV Kopi Nusantara'),
-- ('Susu Full Cream', 'ml', 10000, 0.025, 2000, 'PT Dairy Indonesia'),
-- ('Gula Aren', 'gram', 3000, 0.03, 500, 'UD Gula Manis'),
-- ('Es Batu', 'pcs', 500, 0.5, 100, 'PT Es Bersih'),
-- ('Mie Ramen', 'pcs', 200, 5.0, 50, 'PT Mie Sejahtera'),
-- ('Kuah Tonkotsu', 'ml', 5000, 0.1, 1000, 'PT Ramen Indonesia');
