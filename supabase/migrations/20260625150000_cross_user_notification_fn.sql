-- SECURITY DEFINER function so any authenticated user can push a notification
-- to another user (e.g. tenant → landlord on payment report, landlord → tenant
-- on confirm/reject). The function runs as the DB owner, bypassing RLS on the
-- notifications table for this specific insert path.
--
-- Guards:
--   • The caller must be authenticated (auth.uid() must be non-null).
--   • Only 'property_management' app_id is accepted.
--   • The allowed types are the payment/request cross-user types only.

CREATE OR REPLACE FUNCTION push_notification_for_user(
  p_user_id    UUID,
  p_app_id     TEXT,
  p_type       TEXT,
  p_title      TEXT,
  p_body       TEXT,
  p_reference_id TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Require authenticated caller.
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Only allow known cross-user notification types.
  IF p_type NOT IN (
    'payment_reported', 'payment_confirmed', 'payment_rejected',
    'tenant_request', 'request_update'
  ) THEN
    RAISE EXCEPTION 'type not allowed: %', p_type;
  END IF;

  INSERT INTO notifications
    (user_id, app_id, type, title, body, reference_id, is_read)
  VALUES
    (p_user_id, p_app_id, p_type, p_title, p_body, p_reference_id, false);
END;
$$;

-- Allow any authenticated user to call this function.
GRANT EXECUTE ON FUNCTION push_notification_for_user TO authenticated;
