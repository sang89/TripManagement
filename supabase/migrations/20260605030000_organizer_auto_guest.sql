-- Auto-add the organizer as a going guest when an event is created.

CREATE OR REPLACE FUNCTION create_event(
  p_title           text,
  p_description     text,
  p_location        text,
  p_start_at        timestamptz,
  p_location_lat    double precision DEFAULT NULL,
  p_location_lng    double precision DEFAULT NULL,
  p_end_at          timestamptz      DEFAULT NULL,
  p_capacity        integer          DEFAULT NULL,
  p_event_type      event_type       DEFAULT 'social',
  p_start_location  text             DEFAULT NULL,
  p_start_lat       double precision DEFAULT NULL,
  p_start_lng       double precision DEFAULT NULL,
  p_budget_per_head numeric(10,2)    DEFAULT NULL,
  p_cuisine_tags    text[]           DEFAULT '{}',
  p_rsvp_deadline   timestamptz      DEFAULT NULL,
  p_vibe            text             DEFAULT NULL
)
RETURNS TABLE (
  id              uuid,
  created_by      uuid,
  title           text,
  description     text,
  location        text,
  location_lat    double precision,
  location_lng    double precision,
  start_at        timestamptz,
  end_at          timestamptz,
  capacity        integer,
  invite_code     uuid,
  created_at      timestamptz,
  updated_at      timestamptz,
  event_type      event_type,
  start_location  text,
  start_lat       double precision,
  start_lng       double precision,
  budget_per_head numeric,
  cuisine_tags    text[],
  rsvp_deadline   timestamptz,
  vibe            text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_event_id     uuid;
  v_display_name text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated'
      USING HINT = 'You must be signed in to create an event.';
  END IF;

  INSERT INTO events (
    created_by, title, description, location,
    location_lat, location_lng,
    start_at, end_at, capacity,
    event_type, start_location, start_lat, start_lng,
    budget_per_head, cuisine_tags, rsvp_deadline, vibe
  )
  VALUES (
    v_uid, p_title, p_description, p_location,
    p_location_lat, p_location_lng,
    p_start_at, p_end_at, p_capacity,
    p_event_type, p_start_location, p_start_lat, p_start_lng,
    p_budget_per_head, p_cuisine_tags, p_rsvp_deadline, p_vibe
  )
  RETURNING events.id INTO v_event_id;

  -- Resolve organizer display name from profile, falling back to email.
  SELECT COALESCE(NULLIF(TRIM(up.full_name), ''), u.email, 'Organizer')
  INTO v_display_name
  FROM auth.users u
  LEFT JOIN user_profiles up ON up.user_id = u.id
  WHERE u.id = v_uid;

  INSERT INTO event_guests (event_id, user_id, display_name, status, role)
  VALUES (v_event_id, v_uid, v_display_name, 'going', 'organizer')
  ON CONFLICT DO NOTHING;

  RETURN QUERY
    SELECT
      events.id, events.created_by, events.title, events.description,
      events.location, events.location_lat, events.location_lng,
      events.start_at, events.end_at, events.capacity, events.invite_code,
      events.created_at, events.updated_at,
      events.event_type, events.start_location, events.start_lat, events.start_lng,
      events.budget_per_head, events.cuisine_tags, events.rsvp_deadline, events.vibe
    FROM events
    WHERE events.id = v_event_id;
END;
$$;

-- Backfill: add organizer guest row for all existing events where missing.
INSERT INTO event_guests (event_id, user_id, display_name, status, role)
SELECT
  e.id,
  e.created_by,
  COALESCE(NULLIF(TRIM(up.full_name), ''), u.email, 'Organizer'),
  'going',
  'organizer'
FROM events e
JOIN auth.users u ON u.id = e.created_by
LEFT JOIN user_profiles up ON up.user_id = e.created_by
WHERE NOT EXISTS (
  SELECT 1 FROM event_guests g
  WHERE g.event_id = e.id AND g.user_id = e.created_by
)
ON CONFLICT DO NOTHING;
