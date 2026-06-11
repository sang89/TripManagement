-- ─────────────────────────────────────────────────────────────────────────────
-- Signup sessions migration (remote schema catch-up)
--
-- The remote DB has the OLD signup schema (migrations 000000–000003):
--   • event_guests had: signup_order, attended, signup_confirmed, waitlisted status
--   • events had: recurrence_interval, series_parent_id
--   • RPCs: rsvp_signup_event, cancel_signup, signup_remove_guest,
--           signup_promote_guest, signup_demote_guest, toggle_signup_confirmed,
--           mark_attendance, create_next_session
--   • NO event_sessions or event_session_roster tables
--
-- This migration migrates to the new sessions-based model.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Remove old event_guests signup columns
ALTER TABLE event_guests DROP COLUMN IF EXISTS signup_order;
ALTER TABLE event_guests DROP COLUMN IF EXISTS attended;
ALTER TABLE event_guests DROP COLUMN IF EXISTS signup_confirmed;

-- 2. Remove waitlisted from event_guests status check (only for session roster now)
--    Migrate any existing waitlisted rows to 'going' first.
UPDATE event_guests SET status = 'going' WHERE status = 'waitlisted';
ALTER TABLE event_guests DROP CONSTRAINT IF EXISTS event_guests_status_check;
ALTER TABLE event_guests ADD CONSTRAINT event_guests_status_check
  CHECK (status IN ('going','maybe','declined','pending','accepted','left'));

-- 3. Remove old events recurring columns
ALTER TABLE events DROP COLUMN IF EXISTS recurrence_interval;
ALTER TABLE events DROP COLUMN IF EXISTS series_parent_id;

-- 4. Drop old signup RPCs
DROP FUNCTION IF EXISTS rsvp_signup_event(uuid, text, text, text);
DROP FUNCTION IF EXISTS cancel_signup(uuid);
DROP FUNCTION IF EXISTS signup_remove_guest(uuid);
DROP FUNCTION IF EXISTS signup_promote_guest(uuid);
DROP FUNCTION IF EXISTS signup_demote_guest(uuid);
DROP FUNCTION IF EXISTS toggle_signup_confirmed(uuid, boolean);
DROP FUNCTION IF EXISTS mark_attendance(uuid, boolean);
DROP FUNCTION IF EXISTS create_next_session(uuid, boolean);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. event_sessions — one row per occurrence
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_sessions (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id       uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  session_number integer     NOT NULL,
  start_at       timestamptz NOT NULL,
  end_at         timestamptz,
  invite_code    uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  -- Denormalized counts maintained by trigger (avoids COUNT(*) on roster reads).
  going_count    integer     NOT NULL DEFAULT 0,
  waitlist_count integer     NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, session_number)
);

CREATE INDEX IF NOT EXISTS idx_event_sessions_event_start
  ON event_sessions(event_id, start_at DESC);

ALTER TABLE event_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON event_sessions
  USING (
    EXISTS (SELECT 1 FROM events WHERE id = event_sessions.event_id AND created_by = auth.uid())
  );

CREATE POLICY "members can read sessions" ON event_sessions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_guests
      WHERE event_id = event_sessions.event_id
        AND user_id  = auth.uid()
        AND status NOT IN ('left', 'declined')
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. event_session_roster — per-session signup list
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_session_roster (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id       uuid        NOT NULL REFERENCES event_sessions(id) ON DELETE CASCADE,
  user_id          uuid        REFERENCES auth.users(id),
  display_name     text        NOT NULL,
  email            text,
  phone            text,
  status           text        NOT NULL DEFAULT 'going'
                   CHECK (status IN ('going', 'waitlisted')),
  signup_order     integer,
  attended         boolean,
  signup_confirmed boolean     NOT NULL DEFAULT false,
  signed_up_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_roster_session_order
  ON event_session_roster(session_id, signup_order ASC NULLS LAST);

ALTER TABLE event_session_roster ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON event_session_roster
  USING (
    EXISTS (
      SELECT 1 FROM event_sessions es
      JOIN events e ON e.id = es.event_id
      WHERE es.id = event_session_roster.session_id
        AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "guest reads own entry" ON event_session_roster
  FOR SELECT USING (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Trigger: keep going_count / waitlist_count in sync
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _update_session_roster_counts()
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
                      WHERE session_id = v_session_id AND status = 'waitlisted')
  WHERE id = v_session_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_session_roster_counts ON event_session_roster;
CREATE TRIGGER trg_session_roster_counts
AFTER INSERT OR UPDATE OF status OR DELETE
ON event_session_roster
FOR EACH ROW EXECUTE FUNCTION _update_session_roster_counts();

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. add_event_session RPC
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION add_event_session(
  p_event_id uuid,
  p_start_at timestamptz,
  p_end_at   timestamptz DEFAULT NULL
)
RETURNS TABLE(
  id             uuid,
  event_id       uuid,
  session_number integer,
  start_at       timestamptz,
  end_at         timestamptz,
  invite_code    uuid,
  going_count    integer,
  waitlist_count integer,
  created_at     timestamptz
)
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
  SELECT COALESCE(MAX(session_number), 0) + 1 INTO v_next_num
  FROM event_sessions WHERE event_id = p_event_id;

  RETURN QUERY
  INSERT INTO event_sessions (event_id, session_number, start_at, end_at)
  VALUES (p_event_id, v_next_num, p_start_at, p_end_at)
  RETURNING
    event_sessions.id, event_sessions.event_id, event_sessions.session_number,
    event_sessions.start_at, event_sessions.end_at, event_sessions.invite_code,
    event_sessions.going_count, event_sessions.waitlist_count, event_sessions.created_at;
END;
$$;
GRANT EXECUTE ON FUNCTION add_event_session(uuid, timestamptz, timestamptz) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. rsvp_session RPC
-- ─────────────────────────────────────────────────────────────────────────────
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
  v_event      events%ROWTYPE;
  v_confirmed  bigint;
  v_waitlisted bigint;
  v_next_order integer;
  v_status     text;
  v_roster_id  uuid := gen_random_uuid();
  v_user_id    uuid := auth.uid();
BEGIN
  SELECT * INTO v_session FROM event_sessions WHERE invite_code = p_invite_code;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT * INTO v_event FROM events WHERE id = v_session.event_id FOR UPDATE;
  IF v_event.event_type <> 'signup' THEN RAISE EXCEPTION 'not_a_signup_event'; END IF;

  IF v_event.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_event.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;

  IF v_user_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM event_session_roster
               WHERE session_id = v_session.id AND user_id = v_user_id) THEN
      RAISE EXCEPTION 'already_signed_up';
    END IF;
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE status = 'going'),
    COUNT(*) FILTER (WHERE status = 'waitlisted'),
    COALESCE(MAX(signup_order), 0) + 1
  INTO v_confirmed, v_waitlisted, v_next_order
  FROM event_session_roster WHERE session_id = v_session.id;

  IF v_event.capacity IS NULL OR v_confirmed < v_event.capacity THEN
    v_status := 'going';
  ELSIF v_event.waitlist_enabled THEN
    v_status := 'waitlisted';
  ELSE
    RAISE EXCEPTION 'session_full';
  END IF;

  INSERT INTO event_session_roster
    (id, session_id, user_id, display_name, email, phone, status, signup_order)
  VALUES
    (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone, v_status, v_next_order);

  RETURN QUERY SELECT
    v_roster_id, v_next_order, v_status,
    v_confirmed + CASE WHEN v_status = 'going' THEN 1 ELSE 0 END,
    v_waitlisted + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END,
    v_event.capacity;
END;
$$;
GRANT EXECUTE ON FUNCTION rsvp_session(uuid, text, text, text) TO anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. cancel_session_signup
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION cancel_session_signup(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry   event_session_roster%ROWTYPE;
  v_session event_sessions%ROWTYPE;
  v_event   events%ROWTYPE;
  v_next_wl uuid;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;
  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;
  SELECT * INTO v_event FROM events WHERE id = v_session.event_id FOR UPDATE;
  IF v_event.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_event.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;
  DELETE FROM event_session_roster WHERE id = p_roster_id;
  IF v_entry.status = 'going' THEN
    SELECT id INTO v_next_wl FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'waitlisted'
    ORDER BY signup_order ASC LIMIT 1;
    IF FOUND THEN UPDATE event_session_roster SET status = 'going' WHERE id = v_next_wl; END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION cancel_session_signup(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. session_remove_roster_entry
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION session_remove_roster_entry(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry    event_session_roster%ROWTYPE;
  v_event_id uuid;
  v_next_wl  uuid;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;
  SELECT e.id INTO v_event_id FROM event_sessions es JOIN events e ON e.id = es.event_id
  WHERE es.id = v_entry.session_id;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  DELETE FROM event_session_roster WHERE id = p_roster_id;
  IF v_entry.status = 'going' THEN
    SELECT id INTO v_next_wl FROM event_session_roster
    WHERE session_id = v_entry.session_id AND status = 'waitlisted'
    ORDER BY signup_order ASC LIMIT 1;
    IF FOUND THEN UPDATE event_session_roster SET status = 'going' WHERE id = v_next_wl; END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION session_remove_roster_entry(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. session_promote_roster_entry
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION session_promote_roster_entry(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session_id uuid;
  v_event_id   uuid;
  v_capacity   integer;
  v_confirmed  bigint;
BEGIN
  SELECT session_id INTO v_session_id FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;
  SELECT e.id, e.capacity INTO v_event_id, v_capacity
  FROM event_sessions es JOIN events e ON e.id = es.event_id WHERE es.id = v_session_id;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  IF v_capacity IS NOT NULL THEN
    SELECT COUNT(*) INTO v_confirmed FROM event_session_roster
    WHERE session_id = v_session_id AND status = 'going';
    IF v_confirmed >= v_capacity THEN RAISE EXCEPTION 'session_full'; END IF;
  END IF;
  UPDATE event_session_roster SET status = 'going' WHERE id = p_roster_id AND status = 'waitlisted';
END;
$$;
GRANT EXECUTE ON FUNCTION session_promote_roster_entry(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. session_demote_roster_entry
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION session_demote_roster_entry(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session_id uuid;
  v_event_id   uuid;
  v_max_order  integer;
BEGIN
  SELECT session_id INTO v_session_id FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;
  SELECT e.id INTO v_event_id FROM event_sessions es JOIN events e ON e.id = es.event_id
  WHERE es.id = v_session_id;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  SELECT COALESCE(MAX(signup_order), 0) INTO v_max_order
  FROM event_session_roster WHERE session_id = v_session_id;
  UPDATE event_session_roster SET status = 'waitlisted', signup_order = v_max_order + 1
  WHERE id = p_roster_id AND status = 'going';
END;
$$;
GRANT EXECUTE ON FUNCTION session_demote_roster_entry(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. session_mark_attendance
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION session_mark_attendance(p_roster_id uuid, p_attended boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session_id uuid;
  v_event_id   uuid;
  v_end_at     timestamptz;
BEGIN
  SELECT session_id INTO v_session_id FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;
  SELECT es.end_at, e.id INTO v_end_at, v_event_id
  FROM event_sessions es JOIN events e ON e.id = es.event_id WHERE es.id = v_session_id;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  IF v_end_at IS NOT NULL AND now() < v_end_at THEN RAISE EXCEPTION 'session_not_ended'; END IF;
  UPDATE event_session_roster SET attended = p_attended WHERE id = p_roster_id;
END;
$$;
GRANT EXECUTE ON FUNCTION session_mark_attendance(uuid, boolean) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. toggle_session_confirmed
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION toggle_session_confirmed(p_roster_id uuid, p_confirmed boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session_id    uuid;
  v_event_id      uuid;
  v_entry_user_id uuid;
BEGIN
  SELECT session_id, user_id INTO v_session_id, v_entry_user_id
  FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entry_not_found'; END IF;
  SELECT e.id INTO v_event_id FROM event_sessions es JOIN events e ON e.id = es.event_id
  WHERE es.id = v_session_id;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid())
  AND (v_entry_user_id IS NULL OR v_entry_user_id <> auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  UPDATE event_session_roster SET signup_confirmed = p_confirmed WHERE id = p_roster_id;
END;
$$;
GRANT EXECUTE ON FUNCTION toggle_session_confirmed(uuid, boolean) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. get_session_by_invite_code
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_session_by_invite_code(p_invite_code uuid)
RETURNS TABLE(
  session_id        uuid,
  event_id          uuid,
  session_number    integer,
  title             text,
  description       text,
  location          text,
  location_lat      double precision,
  location_lng      double precision,
  start_at          timestamptz,
  end_at            timestamptz,
  capacity          integer,
  going_count       bigint,
  waitlist_count    bigint,
  organizer_name    text,
  waitlist_enabled  boolean,
  signup_lock_hours integer
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT
    s.id, e.id, s.session_number,
    e.title, e.description, e.location, e.location_lat, e.location_lng,
    s.start_at, s.end_at, e.capacity,
    COUNT(*) FILTER (WHERE r.status = 'going'),
    COUNT(*) FILTER (WHERE r.status = 'waitlisted'),
    (SELECT COALESCE(NULLIF(TRIM(up2.full_name), ''), u2.email)
     FROM auth.users u2 LEFT JOIN user_profiles up2 ON up2.user_id = u2.id
     WHERE u2.id = e.created_by),
    e.waitlist_enabled, e.signup_lock_hours
  FROM event_sessions s
  JOIN events e ON e.id = s.event_id
  LEFT JOIN event_session_roster r ON r.session_id = s.id
  WHERE s.invite_code = p_invite_code
  GROUP BY s.id, s.session_number, s.start_at, s.end_at,
           e.id, e.title, e.description, e.location,
           e.location_lat, e.location_lng, e.capacity,
           e.waitlist_enabled, e.signup_lock_hours, e.created_by;
$$;
GRANT EXECUTE ON FUNCTION get_session_by_invite_code(uuid) TO anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. Update create_event — drop old signature, recreate without recurrence param,
--     auto-create session #1 for signup events.
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS create_event(text,text,text,timestamptz,double precision,double precision,timestamptz,integer,event_type,text,double precision,double precision,numeric,text[],timestamptz,text,text,integer,boolean,integer,text);
DROP FUNCTION IF EXISTS create_event(text,text,text,timestamptz,double precision,double precision,timestamptz,integer,event_type,text,double precision,double precision,numeric,text[],timestamptz,text,text,integer,boolean,integer);

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

  -- Auto-create session #1 for signup events.
  IF p_event_type = 'signup' THEN
    INSERT INTO event_sessions (event_id, session_number, start_at, end_at)
    VALUES (v_event_id, 1, p_start_at, p_end_at);
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. Update get_event_by_invite_code — remove waitlisted from counts
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_event_by_invite_code(uuid);

CREATE OR REPLACE FUNCTION get_event_by_invite_code(p_invite_code uuid)
RETURNS TABLE(
  event_id            uuid,
  event_type          text,
  title               text,
  description         text,
  location            text,
  location_lat        double precision,
  location_lng        double precision,
  start_at            timestamptz,
  end_at              timestamptz,
  capacity            integer,
  going_count         bigint,
  maybe_count         bigint,
  declined_count      bigint,
  waitlist_count      bigint,
  organizer_name      text,
  waitlist_enabled    boolean,
  signup_lock_hours   integer
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT
    e.id, e.event_type::text, e.title, e.description, e.location,
    e.location_lat, e.location_lng, e.start_at, e.end_at, e.capacity,
    COUNT(*) FILTER (WHERE g.status = 'going'),
    COUNT(*) FILTER (WHERE g.status = 'maybe'),
    COUNT(*) FILTER (WHERE g.status = 'declined'),
    0::bigint AS waitlist_count,
    (SELECT COALESCE(NULLIF(TRIM(up2.full_name), ''), u2.email)
     FROM auth.users u2 LEFT JOIN user_profiles up2 ON up2.user_id = u2.id
     WHERE u2.id = e.created_by),
    e.waitlist_enabled, e.signup_lock_hours
  FROM events e
  LEFT JOIN event_guests g ON g.event_id = e.id
  WHERE e.invite_code = p_invite_code
  GROUP BY e.id;
$$;
GRANT EXECUTE ON FUNCTION get_event_by_invite_code(uuid) TO anon, authenticated;
