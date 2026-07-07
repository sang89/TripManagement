-- Fix all server-side notification functions that still hardcode
-- 'property_management' as app_id. After the 20260704 rename migration all
-- new rows must use 'equitypilot'; otherwise NotificationProvider (which
-- filters by app_id = 'equitypilot') never sees them.

-- 1. Payment status trigger (landlord ← tenant reports; tenant ← landlord confirms)
CREATE OR REPLACE FUNCTION notify_payment_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_landlord uuid;
BEGIN
  IF NEW.status = 'tenant_reported'
     AND NEW.status IS DISTINCT FROM OLD.status THEN
    SELECT user_id INTO v_landlord FROM properties WHERE id = NEW.property_id;
    IF v_landlord IS NOT NULL THEN
      INSERT INTO notifications (user_id, app_id, type, title, body, reference_id)
      VALUES (v_landlord, 'equitypilot', 'payment_reported',
              'Payment reported',
              'A tenant reported a rent payment for confirmation.', NEW.id)
      ON CONFLICT DO NOTHING;
    END IF;
  ELSIF NEW.status = 'paid'
        AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO notifications (user_id, app_id, type, title, body, reference_id)
    SELECT tl.tenant_user_id, 'equitypilot', 'payment_confirmed',
           'Payment confirmed',
           'Your landlord confirmed your rent payment.', NEW.id
    FROM tenant_links tl
    WHERE tl.tenant_id = NEW.tenant_id
      AND tl.status = 'active'
      AND tl.tenant_user_id IS NOT NULL
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Tenant request trigger (landlord ← tenant submits a request)
CREATE OR REPLACE FUNCTION notify_landlord_of_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_landlord uuid;
BEGIN
  SELECT user_id INTO v_landlord FROM properties WHERE id = NEW.property_id;
  IF v_landlord IS NOT NULL THEN
    INSERT INTO notifications (user_id, app_id, type, title, body, reference_id)
    VALUES (v_landlord, 'equitypilot', 'tenant_request',
            'New tenant request',
            COALESCE(NULLIF(NEW.title, ''), 'A tenant submitted a request.'),
            NEW.id)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- 3. Invite-claim function (landlord ← tenant joins via invite code)
CREATE OR REPLACE FUNCTION claim_tenant_invite(p_invite_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_link      tenant_links%rowtype;
  v_tenant_id uuid;
  v_email     text;
  v_name      text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth_required'; END IF;

  SELECT * INTO v_link FROM tenant_links
  WHERE invite_token = p_invite_token AND status = 'invited'
  FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'invalid_or_used'); END IF;

  IF v_link.tenant_user_id IS NOT NULL AND v_link.tenant_user_id <> v_uid THEN
    RETURN jsonb_build_object('error', 'not_your_invite');
  END IF;

  v_tenant_id := v_link.tenant_id;

  IF v_tenant_id IS NULL THEN
    SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

    SELECT t.id INTO v_tenant_id
    FROM tenants t
    WHERE t.property_id = v_link.property_id
      AND v_email IS NOT NULL AND lower(t.email) = lower(v_email)
      AND NOT EXISTS (
        SELECT 1 FROM tenant_links tl
        WHERE tl.tenant_id = t.id AND tl.status = 'active'
      )
    LIMIT 1;

    IF v_tenant_id IS NULL THEN
      SELECT nullif(full_name, '') INTO v_name
      FROM user_profiles WHERE user_id = v_uid;
      INSERT INTO tenants (property_id, profile_id, name, email, status)
      VALUES (v_link.property_id,
              (SELECT profile_id FROM properties WHERE id = v_link.property_id),
              COALESCE(v_name, split_part(COALESCE(v_email, ''), '@', 1), 'Tenant'),
              COALESCE(v_email, ''), 'active')
      RETURNING id INTO v_tenant_id;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM tenant_links
    WHERE tenant_id = v_tenant_id AND tenant_user_id = v_uid AND status = 'active'
  ) THEN
    UPDATE tenant_links SET status = 'revoked' WHERE id = v_link.id;
    RETURN jsonb_build_object('success', true, 'already_linked', true,
                              'property_id', v_link.property_id);
  END IF;

  UPDATE tenant_links
    SET tenant_id = v_tenant_id, tenant_user_id = v_uid,
        status = 'active', responded_at = now()
  WHERE id = v_link.id;

  INSERT INTO notifications (user_id, app_id, type, title, body, reference_id)
  VALUES (v_link.landlord_user_id, 'equitypilot', 'request_update',
          'Tenant joined', 'A tenant joined your rental via invite code.',
          v_link.id)
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object('success', true, 'property_id', v_link.property_id,
                            'tenant_id', v_tenant_id);
END;
$$;
