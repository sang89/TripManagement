-- Fix: session_reject_request was doing a plain DELETE, which is unreliable
-- for Supabase Realtime delivery under SECURITY DEFINER (RLS is evaluated after
-- the row is gone, so the rejected user's client never received the event).
--
-- New approach: UPDATE status → 'rejected' first (client receives this UPDATE
-- while the row still exists and can be RLS-verified), then DELETE.
-- The client app handles status = 'rejected' in its Realtime UPDATE handler by
-- clearing the pending state immediately.

-- 1. Extend status constraint to allow 'rejected' as a transient value.
ALTER TABLE event_session_roster
  DROP CONSTRAINT IF EXISTS event_session_roster_status_check;

ALTER TABLE event_session_roster
  ADD CONSTRAINT event_session_roster_status_check
  CHECK (status IN ('going', 'waitlisted', 'pending_review', 'rejected'));

-- 2. Replace session_reject_request to UPDATE then DELETE.
CREATE OR REPLACE FUNCTION session_reject_request(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry   event_session_roster%ROWTYPE;
  v_session event_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;

  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;

  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_session.event_id AND created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  -- Signal rejection via UPDATE first so Supabase Realtime can deliver the
  -- event to the affected user while the row still exists (RLS can verify it).
  UPDATE event_session_roster SET status = 'rejected' WHERE id = p_roster_id;

  -- Then remove the row permanently.
  DELETE FROM event_session_roster WHERE id = p_roster_id;
END;
$$;

GRANT EXECUTE ON FUNCTION session_reject_request(uuid) TO authenticated;
