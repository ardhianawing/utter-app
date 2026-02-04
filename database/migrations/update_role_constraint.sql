-- Drop the old constraint that restricts roles to only specific values (likely admin/cashier)
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Add a new constraint that includes 'kitchen'
ALTER TABLE profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('admin', 'cashier', 'kitchen'));

-- Now try updating the user role again
UPDATE profiles 
SET role = 'kitchen', name = 'Kitchen Staff' 
WHERE phone = '081234567892';
