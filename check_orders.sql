SELECT id, display_id, shift_id, total_amount, cash_received, cash_change, status 
FROM orders 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC 
LIMIT 5;
