-- Fix "column reference 'id' is ambiguous" in add_event_session.
-- RETURNS TABLE output columns (id, event_id, …) shadow same-named table columns
-- inside the function body. Use table aliases everywhere in WHERE clauses.

CREATE OR REPLACE FUNCTION add_event_session(
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
  -- Use table alias to avoid ambiguity with the 'id' output column.
  IF NOT EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = p_event_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  -- Use alias to avoid ambiguity with the 'event_id' output column.
  SELECT COALESCE(MAX(es.session_number), 0) + 1 INTO v_next_num
  FROM event_sessions es WHERE es.event_id = p_event_id;

  RETURN QUERY
    INSERT INTO event_sessions
      (event_id, session_number, start_at, end_at, capacity, waitlist_enabled,
       signup_lock_hours, is_public, requires_approval)
    VALUES
      (p_event_id, v_next_num, p_start_at, p_end_at, p_capacity, p_waitlist_enabled,
       p_signup_lock_hours, p_is_public, p_requires_approval)
    RETURNING
      event_sessions.id, event_sessions.event_id, event_sessions.session_number,
      event_sessions.start_at, event_sessions.end_at, event_sessions.invite_code,
      event_sessions.created_at,
      event_sessions.going_count::integer, event_sessions.waitlist_count::integer,
      event_sessions.capacity, event_sessions.waitlist_enabled,
      event_sessions.signup_lock_hours, event_sessions.is_public,
      event_sessions.requires_approval;
END;
$$;

GRANT EXECUTE ON FUNCTION add_event_session(uuid,timestamptz,timestamptz,integer,boolean,integer,boolean,boolean)
  TO authenticated;
