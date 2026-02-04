-- Fix the role for the Kitchen Staff user
-- Previously it might have been created as 'cashier' default.

UPDATE profiles 
SET role = 'kitchen', name = 'Kitchen Staff' 
WHERE phone = '081234567892';

-- Ensure the kitchen ID is consistent if we want to query by ID later, but phone update is enough for login.
