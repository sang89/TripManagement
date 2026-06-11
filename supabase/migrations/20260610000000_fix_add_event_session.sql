-- Fix "column reference 'id' is ambiguous" in add_event_session.
-- Root cause: RETURNS TABLE(id uuid, ...) creates implicit OUT variables that
-- conflict with column names in the INSERT ... RETURNING clause.
-- Fix: use RETURNS SETOF event_sessions + RETURNING * which is unambiguous.

DROP FUNCTION IF EXISTS add_event_session(uuid, timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION add_event_session(
  p_event_id uuid,
  p_start_at timestamptz,
  p_end_at   timestamptz DEFAULT NULL
)
RETURNS SETOF event_sessions
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_next_num integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND event_type = 'signup') THEN
    RAISE EXCEPTION 'not_a_signup_event';
  END IF;

  SELECT COALESCE(MAX(session_number), 0) + 1
  INTO v_next_num
  FROM event_sessions
  WHERE event_id = p_event_id;

  RETURN QUERY
  INSERT INTO event_sessions (event_id, session_number, start_at, end_at)
  VALUES (p_event_id, v_next_num, p_start_at, p_end_at)
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION add_event_session(uuid, timestamptz, timestamptz) TO authenticated;
