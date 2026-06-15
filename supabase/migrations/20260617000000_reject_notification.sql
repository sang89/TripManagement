-- B1/B15: session_reject_request now notifies the rejected user before deleting.
-- Previously it silently deleted the row — the user only discovered rejection
-- by reopening the app.

CREATE OR REPLACE FUNCTION public.session_reject_request(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry        event_session_roster%ROWTYPE;
  v_session      event_sessions%ROWTYPE;
  v_event_title  text;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;

  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;

  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_session.event_id AND created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  SELECT title INTO v_event_title FROM events WHERE id = v_session.event_id;

  -- Notify the user (skipped for anonymous/guest rows where user_id IS NULL).
  IF v_entry.user_id IS NOT NULL THEN
    PERFORM public.insert_notification(
      v_entry.user_id,
      'session_rejected',
      'Request declined',
      'Your request to join "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || v_session.session_number::text || ' was not approved.',
      v_entry.session_id::text,
      jsonb_build_object('event_id', v_session.event_id)
    );

    PERFORM public.call_push_edge_function(
      v_entry.user_id,
      'session_rejected',
      'Request declined',
      'Your request to join "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || v_session.session_number::text || ' was not approved.',
      jsonb_build_object('session_id', v_entry.session_id, 'event_id', v_session.event_id)
    );
  END IF;

  DELETE FROM event_session_roster WHERE id = p_roster_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.session_reject_request(uuid) TO authenticated;
