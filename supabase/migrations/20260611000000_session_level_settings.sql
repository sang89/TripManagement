-- Move capacity / waitlist_enabled / signup_lock_hours from events to
-- event_sessions.  Each session can now have independent settings.
--
-- Backward-compat: existing sessions inherit the event-level value so no
-- existing data is lost.  Event-level columns are kept (used by non-signup
-- event types and as a historical record) but RPCs now read from the session.

-- ── 1. Add columns to event_sessions ────────────────────────────────────────

ALTER TABLE event_sessions
  ADD COLUMN IF NOT EXISTS capacity         integer,
  ADD COLUMN IF NOT EXISTS waitlist_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS signup_lock_hours integer;

-- ── 2. Migrate existing signup sessions from event-level values ──────────────

UPDATE event_sessions es
SET
  capacity          = e.capacity,
  waitlist_enabled  = e.waitlist_enabled,
  signup_lock_hours = e.signup_lock_hours
FROM events e
WHERE es.event_id = e.id
  AND e.event_type = 'signup';

-- ── 3. Update rsvp_session — read settings from session row ─────────────────
-- Lock the SESSION row (not the parent event) so concurrent signups for
-- different sessions of the same event don't block each other.

CREATE OR REPLACE FUNCTION rsvp_session(
  p_invite_code  uuid,
  p_display_name text,
  p_email        text DEFAULT NULL,
  p_phone        text DEFAULT NULL
)
RETURNS TABLE(
  roster_id        uuid,
  signup_position  integer,
  rsvp_status      text,
  confirmed_count  bigint,
  waitlist_count   bigint,
  session_capacity integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session    event_sessions%ROWTYPE;
  v_event_type event_type;
  v_confirmed  bigint;
  v_waitlisted bigint;
  v_next_order integer;
  v_status     text;
  v_roster_id  uuid := gen_random_uuid();
  v_user_id    uuid := auth.uid();
BEGIN
  -- Lock the session row to serialise concurrent signups for this session.
  SELECT * INTO v_session
  FROM event_sessions WHERE invite_code = p_invite_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT event_type INTO v_event_type FROM events WHERE id = v_session.event_id;
  IF v_event_type <> 'signup' THEN RAISE EXCEPTION 'not_a_signup_event'; END IF;

  -- Signup lock: use session-level hours.
  IF v_session.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_session.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;

  -- Duplicate check.
  IF v_user_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM event_session_roster
               WHERE session_id = v_session.id AND user_id = v_user_id) THEN
      RAISE EXCEPTION 'already_signed_up';
    END IF;
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE status = 'going'),
    COUNT(*) FILTER (WHERE status = 'waitlisted')
  INTO v_confirmed, v_waitlisted
  FROM event_session_roster WHERE session_id = v_session.id;

  -- Use session-level capacity and waitlist settings.
  IF v_session.capacity IS NULL OR v_confirmed < v_session.capacity THEN
    v_status := 'going';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'going';
  ELSIF v_session.waitlist_enabled THEN
    v_status := 'waitlisted';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'waitlisted';
  ELSE
    RAISE EXCEPTION 'session_full';
  END IF;

  INSERT INTO event_session_roster
    (id, session_id, user_id, display_name, email, phone, status, signup_order)
  VALUES
    (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone, v_status, v_next_order);

  RETURN QUERY SELECT
    v_roster_id,
    CASE WHEN v_status = 'going'
         THEN (v_confirmed + 1)::integer
         ELSE (v_waitlisted + 1)::integer
    END,
    v_status,
    v_confirmed + CASE WHEN v_status = 'going'    THEN 1 ELSE 0 END,
    v_waitlisted + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END,
    v_session.capacity;
END;
$$;

GRANT EXECUTE ON FUNCTION rsvp_session(uuid, text, text, text) TO anon, authenticated;

-- ── 4. Update cancel_session_signup — lock check from session ───────────────

CREATE OR REPLACE FUNCTION cancel_session_signup(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry   event_session_roster%ROWTYPE;
  v_session event_sessions%ROWTYPE;
  v_next_wl uuid;
BEGIN
  SELECT * INTO v_entry
  FROM event_session_roster WHERE id = p_roster_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;

  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;

  IF v_session.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_session.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;

  DELETE FROM event_session_roster WHERE id = p_roster_id;

  -- Auto-promote waitlist when a going slot is freed.
  IF v_entry.status = 'going' THEN
    SELECT id INTO v_next_wl FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'waitlisted'
    ORDER BY signup_order ASC LIMIT 1;

    IF v_next_wl IS NOT NULL THEN
      UPDATE event_session_roster SET status = 'going' WHERE id = v_next_wl;
    END IF;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_session_signup(uuid) TO authenticated;

-- ── 5. Update add_event_session — accept per-session settings ───────────────

CREATE OR REPLACE FUNCTION add_event_session(
  p_event_id         uuid,
  p_start_at         timestamptz,
  p_end_at           timestamptz DEFAULT NULL,
  p_capacity         integer     DEFAULT NULL,
  p_waitlist_enabled boolean     DEFAULT true,
  p_signup_lock_hours integer    DEFAULT NULL
)
RETURNS TABLE(
  id             uuid,
  event_id       uuid,
  session_number integer,
  start_at       timestamptz,
  end_at         timestamptz,
  invite_code    uuid,
  created_at     timestamptz,
  going_count    integer,
  waitlist_count integer,
  capacity       integer,
  waitlist_enabled boolean,
  signup_lock_hours integer
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
      (event_id, session_number, start_at, end_at, capacity, waitlist_enabled, signup_lock_hours)
    VALUES
      (p_event_id, v_next_num, p_start_at, p_end_at, p_capacity, p_waitlist_enabled, p_signup_lock_hours)
    RETURNING
      event_sessions.id, event_sessions.event_id, event_sessions.session_number,
      event_sessions.start_at, event_sessions.end_at, event_sessions.invite_code,
      event_sessions.created_at,
      event_sessions.going_count::integer, event_sessions.waitlist_count::integer,
      event_sessions.capacity, event_sessions.waitlist_enabled, event_sessions.signup_lock_hours;
END;
$$;

GRANT EXECUTE ON FUNCTION add_event_session(uuid, timestamptz, timestamptz, integer, boolean, integer)
  TO authenticated;

-- ── 6. Update create_event — pass settings to auto-created Session #1 ───────

CREATE OR REPLACE FUNCTION create_event(
  p_title              text,
  p_description        text,
  p_location           text,
  p_start_at           timestamptz,
  p_location_lat       double precision DEFAULT NULL,
  p_location_lng       double precision DEFAULT NULL,
  p_end_at             timestamptz      DEFAULT NULL,
  p_capacity           integer          DEFAULT NULL,
  p_event_type         event_type       DEFAULT 'social',
  p_start_location     text             DEFAULT NULL,
  p_start_lat          double precision DEFAULT NULL,
  p_start_lng          double precision DEFAULT NULL,
  p_budget_per_head    numeric(10,2)    DEFAULT NULL,
  p_cuisine_tags       text[]           DEFAULT '{}',
  p_rsvp_deadline      timestamptz      DEFAULT NULL,
  p_vibe               text             DEFAULT NULL,
  p_honoree_name       text             DEFAULT NULL,
  p_birth_year         integer          DEFAULT NULL,
  p_waitlist_enabled   boolean          DEFAULT true,
  p_signup_lock_hours  integer          DEFAULT NULL
)
RETURNS TABLE (
  id                       uuid,
  created_by               uuid,
  title                    text,
  description              text,
  location                 text,
  location_lat             double precision,
  location_lng             double precision,
  start_at                 timestamptz,
  end_at                   timestamptz,
  capacity                 integer,
  invite_code              uuid,
  created_at               timestamptz,
  updated_at               timestamptz,
  event_type               event_type,
  start_location           text,
  start_lat                double precision,
  start_lng                double precision,
  budget_per_head          numeric,
  cuisine_tags             text[],
  rsvp_deadline            timestamptz,
  vibe                     text,
  honoree_name             text,
  birth_year               integer,
  predictions_revealed_at  timestamptz,
  wishes_revealed_at       timestamptz,
  waitlist_enabled         boolean,
  signup_lock_hours        integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
    created_by, title, description, location, location_lat, location_lng,
    start_at, end_at, capacity, event_type, start_location, start_lat, start_lng,
    budget_per_head, cuisine_tags, rsvp_deadline, vibe, honoree_name, birth_year,
    waitlist_enabled, signup_lock_hours
  ) VALUES (
    v_uid, p_title, p_description, p_location, p_location_lat, p_location_lng,
    p_start_at, p_end_at, p_capacity, p_event_type, p_start_location, p_start_lat, p_start_lng,
    p_budget_per_head, p_cuisine_tags, p_rsvp_deadline, p_vibe, p_honoree_name, p_birth_year,
    p_waitlist_enabled, p_signup_lock_hours
  ) RETURNING events.id INTO v_event_id;

  SELECT COALESCE(NULLIF(TRIM(up.full_name), ''), u.email, 'Organizer')
  INTO v_display_name
  FROM auth.users u LEFT JOIN user_profiles up ON up.user_id = u.id
  WHERE u.id = v_uid;

  INSERT INTO event_guests (event_id, user_id, display_name, status, role)
  VALUES (v_event_id, v_uid, v_display_name, 'going', 'organizer')
  ON CONFLICT DO NOTHING;

  -- Auto-create session #1 for signup events, inheriting the settings.
  IF p_event_type = 'signup' THEN
    INSERT INTO event_sessions
      (event_id, session_number, start_at, end_at,
       capacity, waitlist_enabled, signup_lock_hours)
    VALUES
      (v_event_id, 1, p_start_at, p_end_at,
       p_capacity, p_waitlist_enabled, p_signup_lock_hours);
  END IF;

  RETURN QUERY
    SELECT
      events.id, events.created_by, events.title, events.description,
      events.location, events.location_lat, events.location_lng,
      events.start_at, events.end_at, events.capacity, events.invite_code,
      events.created_at, events.updated_at, events.event_type,
      events.start_location, events.start_lat, events.start_lng,
      events.budget_per_head, events.cuisine_tags, events.rsvp_deadline, events.vibe,
      events.honoree_name, events.birth_year,
      events.predictions_revealed_at, events.wishes_revealed_at,
      events.waitlist_enabled, events.signup_lock_hours
    FROM events WHERE events.id = v_event_id;
END;
$$;

GRANT EXECUTE ON FUNCTION create_event(text,text,text,timestamptz,double precision,double precision,timestamptz,integer,event_type,text,double precision,double precision,numeric,text[],timestamptz,text,text,integer,boolean,integer)
  TO authenticated;
