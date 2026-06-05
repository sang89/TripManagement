-- Quick Bites event type + feature columns
-- Adds the quick_bites EventType and supporting fields for:
--   budget per head, cuisine tags, RSVP deadline, vibe picker,
--   and restaurant-vote metadata on poll options.

-- 1. Add quick_bites to event_type enum
ALTER TYPE event_type ADD VALUE IF NOT EXISTS 'quick_bites';

-- 2. New Quick Bites columns on events
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS budget_per_head numeric(10,2),
  ADD COLUMN IF NOT EXISTS cuisine_tags    text[]     NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS rsvp_deadline   timestamptz,
  ADD COLUMN IF NOT EXISTS vibe            text;

-- 3. Restaurant Vote metadata on poll options (nullable — used only for restaurant polls)
ALTER TABLE event_poll_options
  ADD COLUMN IF NOT EXISTS place_metadata jsonb;

-- 4. Update create_event RPC to accept and return new fields.
--    New params are all optional with safe defaults so existing callers are unaffected.
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
    RETURNING
      events.id, events.created_by, events.title, events.description,
      events.location, events.location_lat, events.location_lng,
      events.start_at, events.end_at, events.capacity, events.invite_code,
      events.created_at, events.updated_at,
      events.event_type, events.start_location, events.start_lat, events.start_lng,
      events.budget_per_head, events.cuisine_tags, events.rsvp_deadline, events.vibe;
END;
$$;
