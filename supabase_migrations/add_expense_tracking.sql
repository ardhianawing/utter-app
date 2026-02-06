-- ============================================================
-- Migration: Add Expense Tracking Module
-- Date: 2026-02-06
-- Description: Tables for expense management and budget tracking
-- ============================================================

-- Step 1: Create expense categories table
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50), -- 'restaurant', 'bolt', 'people', 'build', etc.
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Step 2: Create expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES expense_categories(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    description TEXT NOT NULL,
    payment_method VARCHAR(20) NOT NULL, -- 'CASH', 'TRANSFER', 'DEBIT'
    receipt_url TEXT,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMP,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Step 3: Create budgets table
CREATE TABLE IF NOT EXISTS budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES expense_categories(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL CHECK (year >= 2020),
    notes TEXT,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(category_id, month, year)
);

-- Step 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by);
CREATE INDEX IF NOT EXISTS idx_budgets_period ON budgets(year, month);

-- Step 5: Insert default expense categories
INSERT INTO expense_categories (name, description, icon) VALUES
('Sewa Tempat', 'Biaya sewa gedung/lokasi usaha', 'home'),
('Listrik & Air', 'Tagihan utilitas (listrik, air, gas)', 'bolt'),
('Gaji Karyawan', 'Gaji staff & bonus', 'people'),
('Bahan Baku', 'Pembelian bahan baku (groceries)', 'shopping_cart'),
('Perawatan', 'Maintenance peralatan & gedung', 'build'),
('Marketing', 'Biaya promosi & iklan', 'campaign'),
('Transportasi', 'Bensin, transport, delivery', 'local_shipping'),
('Lain-lain', 'Pengeluaran lain-lain', 'more_horiz')
ON CONFLICT (name) DO NOTHING;

-- Step 6: Add comments for documentation
COMMENT ON TABLE expense_categories IS 'Master data kategori pengeluaran';
COMMENT ON TABLE expenses IS 'Log semua pengeluaran bisnis';
COMMENT ON TABLE budgets IS 'Budget bulanan per kategori';

COMMENT ON COLUMN expenses.payment_method IS 'CASH, TRANSFER, atau DEBIT';
COMMENT ON COLUMN expenses.approved_by IS 'Admin yang approve expense (untuk workflow approval)';

-- Step 7: Create view for expense summary
CREATE OR REPLACE VIEW expense_summary_monthly AS
SELECT
    e.category_id,
    ec.name as category_name,
    EXTRACT(YEAR FROM e.expense_date)::INTEGER as year,
    EXTRACT(MONTH FROM e.expense_date)::INTEGER as month,
    COUNT(e.id) as expense_count,
    SUM(e.amount) as total_amount,
    AVG(e.amount) as avg_amount
FROM expenses e
LEFT JOIN expense_categories ec ON e.category_id = ec.id
GROUP BY e.category_id, ec.name, year, month
ORDER BY year DESC, month DESC;

-- Step 8: Create function to get budget vs actual
CREATE OR REPLACE FUNCTION get_budget_vs_actual(
    p_month INTEGER,
    p_year INTEGER
)
RETURNS TABLE (
    category_id UUID,
    category_name VARCHAR,
    budget_amount DECIMAL,
    actual_amount DECIMAL,
    variance DECIMAL,
    variance_percent DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.category_id,
        ec.name as category_name,
        b.amount as budget_amount,
        COALESCE(SUM(e.amount), 0) as actual_amount,
        b.amount - COALESCE(SUM(e.amount), 0) as variance,
        CASE
            WHEN b.amount > 0 THEN
                ((b.amount - COALESCE(SUM(e.amount), 0)) / b.amount * 100)
            ELSE 0
        END as variance_percent
    FROM budgets b
    LEFT JOIN expense_categories ec ON b.category_id = ec.id
    LEFT JOIN expenses e ON
        e.category_id = b.category_id
        AND EXTRACT(MONTH FROM e.expense_date) = p_month
        AND EXTRACT(YEAR FROM e.expense_date) = p_year
    WHERE b.month = p_month AND b.year = p_year
    GROUP BY b.category_id, ec.name, b.amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Verification Queries
-- ============================================================
-- SELECT * FROM expense_categories;
-- SELECT * FROM expenses ORDER BY expense_date DESC;
-- SELECT * FROM budgets;
-- SELECT * FROM expense_summary_monthly;
-- SELECT * FROM get_budget_vs_actual(2, 2026);

-- ============================================================
-- SUCCESS! Expense Tracking Module Ready
-- ============================================================
