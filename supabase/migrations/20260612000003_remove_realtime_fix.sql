-- Fix: session_remove_roster_entry did a plain DELETE, same root cause as the
-- reject fix (20260612000002). The kicked user's device never received the
-- Realtime DELETE because Supabase couldn't verify RLS after the row was gone.
--
-- Fix: UPDATE status → 'removed' first so the Realtime UPDATE reaches the
-- user while the row still exists, then DELETE.

-- 1. Extend status constraint to allow 'removed' as a transient signal.
ALTER TABLE event_session_roster
  DROP CONSTRAINT IF EXISTS event_session_roster_status_check;

ALTER TABLE event_session_roster
  ADD CONSTRAINT event_session_roster_status_check
  CHECK (status IN ('going', 'waitlisted', 'pending_review', 'rejected', 'removed'));

-- 2. Replace session_remove_roster_entry.
CREATE OR REPLACE FUNCTION session_remove_roster_entry(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry    event_session_roster%ROWTYPE;
  v_event_id uuid;
  v_next_wl  uuid;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM event_sessions es JOIN events e ON e.id = es.event_id
  WHERE es.id = v_entry.session_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Signal removal via UPDATE so Supabase Realtime delivers the event to the
  -- affected user while the row still exists (same pattern as session_reject_request).
  UPDATE event_session_roster SET status = 'removed' WHERE id = p_roster_id;

  DELETE FROM event_session_roster WHERE id = p_roster_id;

  -- Auto-promote the first waitlisted user if a going slot was freed.
  IF v_entry.status = 'going' THEN
    SELECT id INTO v_next_wl FROM event_session_roster
    WHERE session_id = v_entry.session_id AND status = 'waitlisted'
    ORDER BY signup_order ASC LIMIT 1;
    IF FOUND THEN
      UPDATE event_session_roster SET status = 'going' WHERE id = v_next_wl;
    END IF;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION session_remove_roster_entry(uuid) TO authenticated;
