-- Isolate push notifications by app.
--
-- device_tokens is shared between TripManagement and PropertyManagement
-- (same Supabase project). Without an app discriminator, send-push-notification
-- queries ALL tokens for a user and sends FCM to both apps — so a TripManagement
-- session_removed notification fires a push inside PropertyManagement.
--
-- Fix: add an `app` column. Existing rows (all from PropertyManagement) get the
-- default 'property_management'. TripManagement tokens are registered with
-- 'trip_management'. Every TripManagement push function filters by this column.

ALTER TABLE device_tokens
  ADD COLUMN IF NOT EXISTS app text NOT NULL DEFAULT 'property_management';

-- Index so the push functions don't full-scan device_tokens.
CREATE INDEX IF NOT EXISTS device_tokens_user_app_idx
  ON device_tokens (user_id, app);

-- Update call_push_edge_function to pass app_id so send-push-notification
-- can filter tokens to the correct app.
CREATE OR REPLACE FUNCTION public.call_push_edge_function(
  p_user_id uuid,
  p_type    text,
  p_title   text,
  p_body    text,
  p_data    jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_service_role_key IS NOT NULL THEN
    PERFORM net.http_post(
      url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                 || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body    := jsonb_build_object(
        'user_id', p_user_id,
        'type',    p_type,
        'title',   p_title,
        'body',    p_body,
        'data',    p_data,
        'app_id',  'trip_management'
      )
    );
  END IF;
END;
$$;

-- Update broadcast_notification to use app-scoped channel so PropertyManagement
-- (which may subscribe to notifications_{userId}) never receives TripManagement
-- broadcasts.
CREATE OR REPLACE FUNCTION public.broadcast_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
BEGIN
  IF NEW.is_read = true THEN RETURN NEW; END IF;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_service_role_key IS NOT NULL THEN
    PERFORM net.http_post(
      url     := 'https://qgeocaectbdfonrorwco.supabase.co/realtime/v1/api/broadcast',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'apikey',        v_service_role_key,
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body    := jsonb_build_object(
        'messages', jsonb_build_array(
          jsonb_build_object(
            'topic',   'realtime:trip_notifications_' || NEW.user_id::text,
            'event',   'new_notification',
            'payload', jsonb_build_object('type', NEW.type)
          )
        )
      )
    );
  END IF;
  RETURN NEW;
END;
$$;
