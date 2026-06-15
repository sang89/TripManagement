-- Organizer deletes a session.
-- Marks active roster entries as 'removed' first (triggers per-user notifications),
-- then deletes the session row (CASCADE cleans up remaining roster entries).

CREATE OR REPLACE FUNCTION public.delete_event_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT es.event_id INTO v_event_id
    FROM event_sessions es
    JOIN events e ON e.id = es.event_id
   WHERE es.id = p_session_id
     AND e.created_by = auth.uid();

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  -- Mark active entries as 'removed' so notify_session_removed fires for each user.
  UPDATE event_session_roster
     SET status = 'removed'
   WHERE session_id = p_session_id
     AND status IN ('going', 'waitlisted', 'pending_review');

  DELETE FROM event_sessions WHERE id = p_session_id;
END;
$$;
