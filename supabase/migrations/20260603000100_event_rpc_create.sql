-- RPC wrapper for creating an event.
-- SECURITY DEFINER bypasses RLS so the insert always succeeds for authenticated
-- users even if PostgREST RLS evaluation has issues with the new publishable
-- key format.  auth.uid() is still used to enforce that the caller is signed in
-- and to set created_by.

CREATE FUNCTION create_event(
  p_title        text,
  p_description  text,
  p_location     text,
  p_start_at     timestamptz,
  p_location_lat double precision DEFAULT NULL,
  p_location_lng double precision DEFAULT NULL,
  p_end_at       timestamptz      DEFAULT NULL,
  p_capacity     integer          DEFAULT NULL
)
RETURNS TABLE (
  id           uuid,
  created_by   uuid,
  title        text,
  description  text,
  location     text,
  location_lat double precision,
  location_lng double precision,
  start_at     timestamptz,
  end_at       timestamptz,
  capacity     integer,
  invite_code  uuid,
  created_at   timestamptz,
  updated_at   timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated'
      USING HINT = 'You must be signed in to create an event.';
  END IF;

  RETURN QUERY
    INSERT INTO events (
      created_by, title, description, location,
      location_lat, location_lng,
      start_at, end_at, capacity
    )
    VALUES (
      v_uid, p_title, p_description, p_location,
      p_location_lat, p_location_lng,
      p_start_at, p_end_at, p_capacity
    )
    RETURNING
      events.id, events.created_by, events.title, events.description,
      events.location, events.location_lat, events.location_lng,
      events.start_at, events.end_at, events.capacity, events.invite_code,
      events.created_at, events.updated_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION create_event FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION create_event TO authenticated;
