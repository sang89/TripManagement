-- ─────────────────────────────────────────────────────────────────────────────
-- Add delete_queue_activity RPC.
--
-- "Evict All" previously called clear_queue, which deleted all entries but
-- left an empty queue row behind. The new behaviour removes the row entirely:
--   • session_queue_entries.activity_id has ON DELETE CASCADE, so all entries
--     are wiped automatically with no extra work.
--   • The Realtime DELETE event on session_queue_activities triggers
--     handleQueueActivityDelete on all connected clients, removing the row
--     from every participant's UI in real time.
-- Only the event organizer may call this function.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.delete_queue_activity(p_activity_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_event_id uuid;
BEGIN
  SELECT es.event_id INTO v_event_id
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'activity_not_found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_event_id AND created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM session_queue_activities WHERE id = p_activity_id;
  -- CASCADE deletes all session_queue_entries for this activity.
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_queue_activity(uuid) TO authenticated;
