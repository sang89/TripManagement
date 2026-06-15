-- Notify a user when they are removed from a session by the organizer.
-- session_remove_roster_entry signals removal via UPDATE status='removed'
-- before the DELETE, so this trigger fires on that transient UPDATE.

CREATE OR REPLACE FUNCTION public.notify_session_removed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_title    text;
  v_event_id       uuid;
  v_session_number int;
BEGIN
  IF NEW.status = 'removed' AND NEW.user_id IS NOT NULL THEN
    SELECT e.title, e.id, es.session_number
      INTO v_event_title, v_event_id, v_session_number
    FROM event_sessions es
    JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    PERFORM public.insert_notification(
      NEW.user_id,
      'session_removed',
      'Removed from session',
      'You''ve been removed from "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      NEW.user_id,
      'session_removed',
      'Removed from session',
      'You''ve been removed from "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_session_removed
  AFTER UPDATE ON public.event_session_roster
  FOR EACH ROW EXECUTE FUNCTION public.notify_session_removed();
