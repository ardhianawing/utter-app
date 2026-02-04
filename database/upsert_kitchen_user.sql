INSERT INTO profiles (id, name, role, phone, pin, is_active) VALUES ('kitchen-user-id', 'Kitchen Staff', 'kitchen', '081234567892', '222222', true) ON CONFLICT (phone) DO UPDATE SET role = 'kitchen';
