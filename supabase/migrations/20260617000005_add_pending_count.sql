-- B5: Add pending_count to event_sessions so the pending-review badge on the
-- session card is visible without expanding the roster first.

ALTER TABLE event_sessions
  ADD COLUMN IF NOT EXISTS pending_count integer NOT NULL DEFAULT 0;

-- Backfill from existing roster data.
UPDATE event_sessions
SET pending_count = (
  SELECT COUNT(*)
  FROM event_session_roster
  WHERE session_id = event_sessions.id
    AND status = 'pending_review'
);

-- Update the roster-count trigger to maintain pending_count alongside
-- going_count and waitlist_count.
CREATE OR REPLACE FUNCTION public._update_session_roster_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_session_id uuid;
BEGIN
  v_session_id := COALESCE(NEW.session_id, OLD.session_id);
  UPDATE event_sessions
  SET
    going_count    = (SELECT COUNT(*) FROM event_session_roster
                      WHERE session_id = v_session_id AND status = 'going'),
    waitlist_count = (SELECT COUNT(*) FROM event_session_roster
                      WHERE session_id = v_session_id AND status = 'waitlisted'),
    pending_count  = (SELECT COUNT(*) FROM event_session_roster
                      WHERE session_id = v_session_id AND status = 'pending_review')
  WHERE id = v_session_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Now that pending_count column exists, re-create add_event_session to return it.
-- Must DROP first — PostgreSQL forbids changing a function's return type via OR REPLACE.
DROP FUNCTION IF EXISTS public.add_event_session(uuid,timestamptz,timestamptz,integer,boolean,integer,boolean,boolean);

CREATE FUNCTION public.add_event_session(
  p_event_id           uuid,
  p_start_at           timestamptz,
  p_end_at             timestamptz DEFAULT NULL,
  p_capacity           integer     DEFAULT NULL,
  p_waitlist_enabled   boolean     DEFAULT true,
  p_signup_lock_hours  integer     DEFAULT NULL,
  p_is_public          boolean     DEFAULT true,
  p_requires_approval  boolean     DEFAULT false
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
  pending_count     integer,
  capacity          integer,
  waitlist_enabled  boolean,
  signup_lock_hours integer,
  is_public         boolean,
  requires_approval boolean
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
       signup_lock_hours, is_public, requires_approval)
    VALUES
      (p_event_id, v_next_num, p_start_at,
       COALESCE(p_end_at, p_start_at + interval '2 hours'),
       p_capacity, p_waitlist_enabled,
       p_signup_lock_hours, p_is_public, p_requires_approval)
    RETURNING
      event_sessions.id, event_sessions.event_id, event_sessions.session_number,
      event_sessions.start_at, event_sessions.end_at, event_sessions.invite_code,
      event_sessions.created_at,
      event_sessions.going_count::integer, event_sessions.waitlist_count::integer,
      event_sessions.pending_count::integer,
      event_sessions.capacity, event_sessions.waitlist_enabled,
      event_sessions.signup_lock_hours, event_sessions.is_public,
      event_sessions.requires_approval;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_event_session(uuid,timestamptz,timestamptz,integer,boolean,integer,boolean,boolean)
  TO authenticated;
