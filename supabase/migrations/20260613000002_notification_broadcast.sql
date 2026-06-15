-- Supabase Realtime cannot deliver Postgres Changes events from SECURITY DEFINER
-- function inserts because auth.uid() is NULL in the WAL broadcast context.
--
-- Fix: add a trigger on notifications that fires on every INSERT and sends a
-- Supabase Realtime Broadcast message to the user's notification channel.
-- Broadcast bypasses RLS entirely, so delivery is guaranteed.
-- Flutter subscribes to the broadcast channel and calls reload() on receipt.

CREATE OR REPLACE FUNCTION public.broadcast_notification()
RETURNS trigger
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

DROP TRIGGER IF EXISTS on_notification_inserted ON public.notifications;

CREATE TRIGGER on_notification_inserted
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_notification();
