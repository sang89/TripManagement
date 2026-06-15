-- Fix: ON CONFLICT DO NOTHING in insert_notification silently drops repeated
-- notifications for the same (user_id, type, reference_id) combination.
-- When the organizer or user tests the same action more than once, the second+
-- notifications were swallowed, so the bell never updated and polling found
-- nothing new (the row was already there from the first attempt).
--
-- Fix 1: replace DO NOTHING with DO UPDATE so repeat actions refresh the
-- notification to unread with a fresh timestamp.
--
-- Fix 2: change broadcast_notification to fire on INSERT OR UPDATE so the
-- Flutter client gets a push when an upserted notification is refreshed (not
-- just on brand-new inserts).  Skip mark-as-read UPDATEs (is_read = true).

-- ── 1. Fix insert_notification ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.insert_notification(
  p_user_id      uuid,
  p_type         text,
  p_title        text,
  p_body         text,
  p_reference_id text  DEFAULT NULL,
  p_metadata     jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, body, reference_id, metadata)
  VALUES (p_user_id, p_type, p_title, p_body, p_reference_id, p_metadata)
  ON CONFLICT (user_id, type, reference_id) WHERE reference_id IS NOT NULL
  DO UPDATE SET
    title      = EXCLUDED.title,
    body       = EXCLUDED.body,
    metadata   = EXCLUDED.metadata,
    is_read    = false,
    created_at = now();
END;
$$;

-- ── 2. Fix broadcast_notification to fire on INSERT OR UPDATE ─────────────────

CREATE OR REPLACE FUNCTION public.broadcast_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
BEGIN
  -- Don't broadcast when the user marks a notification as read — only broadcast
  -- when a notification is new or refreshed (is_read = false).
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
            'topic',   'realtime:notifications_' || NEW.user_id::text,
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

-- Drop the INSERT-only trigger and recreate it for INSERT OR UPDATE.
DROP TRIGGER IF EXISTS on_notification_inserted ON public.notifications;

CREATE TRIGGER on_notification_inserted
  AFTER INSERT OR UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_notification();
