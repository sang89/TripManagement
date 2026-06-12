-- Add is_public flag to event_sessions.
--
-- Public  (default): visible to all event members in the session list.
-- Private:           hidden from the session list; members can only join via
--                    QR code or invite link. Once a member joins, the session
--                    becomes visible to them (their roster entry unlocks it).

ALTER TABLE event_sessions
  ADD COLUMN IF NOT EXISTS is_public boolean NOT NULL DEFAULT true;

-- ── Update add_event_session RPC ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION add_event_session(
  p_event_id          uuid,
  p_start_at          timestamptz,
  p_end_at            timestamptz DEFAULT NULL,
  p_capacity          integer     DEFAULT NULL,
  p_waitlist_enabled  boolean     DEFAULT true,
  p_signup_lock_hours integer     DEFAULT NULL,
  p_is_public         boolean     DEFAULT true
)
RETURNS TABLE(
  id                uuid,
  event_id          uuid,
  session_number    integer,
  start_at          timestamptz,
  end_at            timestamptz,
  invite_code       uuid,
  created_at        timestamptz,
  going_count       integer,
  waitlist_count    integer,
  capacity          integer,
  waitlist_enabled  boolean,
  signup_lock_hours integer,
  is_public         boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_next_num integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  SELECT COALESCE(MAX(session_number), 0) + 1 INTO v_next_num
  FROM event_sessions WHERE event_id = p_event_id;

  RETURN QUERY
    INSERT INTO event_sessions
      (event_id, session_number, start_at, end_at, capacity, waitlist_enabled,
       signup_lock_hours, is_public)
    VALUES
      (p_event_id, v_next_num, p_start_at, p_end_at, p_capacity, p_waitlist_enabled,
       p_signup_lock_hours, p_is_public)
    RETURNING
      event_sessions.id, event_sessions.event_id, event_sessions.session_number,
      event_sessions.start_at, event_sessions.end_at, event_sessions.invite_code,
      event_sessions.created_at,
      event_sessions.going_count::integer, event_sessions.waitlist_count::integer,
      event_sessions.capacity, event_sessions.waitlist_enabled,
      event_sessions.signup_lock_hours, event_sessions.is_public;
END;
$$;

GRANT EXECUTE ON FUNCTION add_event_session(uuid, timestamptz, timestamptz, integer, boolean, integer, boolean)
  TO authenticated;

-- ── Update "members can read sessions" RLS policy ─────────────────────────────
-- Public sessions  → any event member can see (existing behaviour).
-- Private sessions → only visible to members who have joined via QR/invite
--                    (i.e. have a roster entry). Organiser sees all via the
--                    existing "organizer full access" permissive policy.

DROP POLICY IF EXISTS "members can read sessions" ON event_sessions;

CREATE POLICY "members can read sessions" ON event_sessions
  FOR SELECT USING (
    -- Public: any accepted/pending event member can see
    (
      is_public = true
      AND EXISTS (
        SELECT 1 FROM event_guests
        WHERE event_id = event_sessions.event_id
          AND user_id  = auth.uid()
          AND status NOT IN ('left', 'declined')
      )
    )
    -- Private: visible only to members who joined via QR/invite link
    OR EXISTS (
      SELECT 1 FROM event_session_roster
      WHERE session_id = event_sessions.id
        AND user_id    = auth.uid()
    )
  );
