-- Mark a session as done: wipes all activity-tab data (queues + free pool)
-- while leaving the roster intact. Only the event organizer can call this.

CREATE OR REPLACE FUNCTION public.mark_session_done(
  p_session_id uuid,
  p_event_id   uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Verify caller is the organizer of this event.
  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = p_event_id AND created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  -- Verify the session belongs to the event.
  IF NOT EXISTS (
    SELECT 1 FROM event_sessions WHERE id = p_session_id AND event_id = p_event_id
  ) THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  -- Delete queue entries first (FK child of session_queue_activities).
  DELETE FROM session_queue_entries
  WHERE activity_id IN (
    SELECT id FROM session_queue_activities WHERE session_id = p_session_id
  );

  -- Delete queue activities.
  DELETE FROM session_queue_activities WHERE session_id = p_session_id;

  -- Mark inactive, lock override, and set end_at = now() so it appears in Past sessions.
  UPDATE event_sessions
  SET is_active          = false,
      is_active_override = true,
      end_at             = CASE
                             WHEN end_at IS NULL OR end_at > NOW() THEN NOW()
                             ELSE end_at
                           END
  WHERE id = p_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_session_done(uuid, uuid) TO authenticated;
