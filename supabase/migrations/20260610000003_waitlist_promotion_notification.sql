-- Trigger: fire send-waitlist-promoted-notification when a roster entry
-- transitions from status='waitlisted' to status='going'.
-- Only fires when user_id IS NOT NULL (anonymous signups have no device tokens).

CREATE OR REPLACE FUNCTION public.handle_waitlist_promotion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
BEGIN
  -- Only act on waitlisted → going transitions for authenticated users
  IF OLD.status = 'waitlisted' AND NEW.status = 'going' AND NEW.user_id IS NOT NULL THEN
    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    IF v_service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                   || '/functions/v1/send-waitlist-promoted-notification',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body    := jsonb_build_object(
          'roster_id',  NEW.id,
          'session_id', NEW.session_id,
          'user_id',    NEW.user_id
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_waitlist_promoted
  AFTER UPDATE ON public.event_session_roster
  FOR EACH ROW EXECUTE FUNCTION public.handle_waitlist_promotion();
