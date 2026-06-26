-- Add payment_rejected to the notifications type check constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'lease_expiry',
    'system',
    'monthly_summary',
    'rent_overdue',
    'rent_reminder',
    'tenant_invite',
    'tenant_request',
    'payment_reported',
    'payment_confirmed',
    'payment_rejected',
    'request_update'
  ));
