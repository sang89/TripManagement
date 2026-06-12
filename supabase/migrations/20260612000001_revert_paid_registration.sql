-- Revert 20260612000000_paid_session_registration.
-- Removes all payment infrastructure; restores RPCs to their state after
-- 20260611000005_session_requires_approval.

-- ── 1. Drop payment columns ───────────────────────────────────────────────────

ALTER TABLE event_sessions DROP CONSTRAINT IF EXISTS event_sessions_payment_mode_check;
ALTER TABLE event_sessions DROP COLUMN IF EXISTS price_cents;
ALTER TABLE event_sessions DROP COLUMN IF EXISTS currency;
ALTER TABLE event_sessions DROP COLUMN IF EXISTS payment_mode;

ALTER TABLE event_session_roster DROP CONSTRAINT IF EXISTS event_session_roster_payment_status_check;
ALTER TABLE event_session_roster DROP COLUMN IF EXISTS payment_status;
ALTER TABLE event_session_roster DROP COLUMN IF EXISTS stripe_payment_intent_id;
ALTER TABLE event_session_roster DROP COLUMN IF EXISTS paid_at;

ALTER TABLE user_profiles DROP COLUMN IF EXISTS stripe_connect_account_id;
ALTER TABLE user_profiles DROP COLUMN IF EXISTS stripe_connect_charges_enabled;

-- ── 2. Drop new RPCs ──────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS mark_roster_paid(uuid);
DROP FUNCTION IF EXISTS update_connect_account(uuid, text, boolean);

-- ── 3. Restore add_event_session (without payment params) ────────────────────

DROP FUNCTION IF EXISTS add_event_session(uuid,timestamptz,timestamptz,integer,boolean,integer,boolean,boolean,integer,text,text);

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
  IF NOT EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = p_event_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

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

-- ── 4. Restore get_session_by_invite_code (without payment/connect fields) ───

DROP FUNCTION IF EXISTS get_session_by_invite_code(uuid);

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
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    e.id,
    s.session_number,
    e.title,
    e.description,
    e.location,
    e.location_lat,
    e.location_lng,
    s.start_at,
    s.end_at,
    s.capacity,
    COUNT(*) FILTER (WHERE r.status = 'going')      AS going_count,
    COUNT(*) FILTER (WHERE r.status = 'waitlisted') AS waitlist_count,
    (
      SELECT COALESCE(NULLIF(TRIM(up2.full_name), ''), u2.email)
      FROM auth.users u2
      LEFT JOIN user_profiles up2 ON up2.user_id = u2.id
      WHERE u2.id = e.created_by
    ) AS organizer_name,
    s.waitlist_enabled,
    s.signup_lock_hours
  FROM event_sessions s
  JOIN events e ON e.id = s.event_id
  LEFT JOIN event_session_roster r ON r.session_id = s.id
  WHERE s.invite_code = p_invite_code
  GROUP BY s.id, s.session_number, s.start_at, s.end_at,
           e.id, e.title, e.description, e.location,
           e.location_lat, e.location_lng, e.capacity,
           s.capacity, s.waitlist_enabled, s.signup_lock_hours, e.created_by;
$$;

GRANT EXECUTE ON FUNCTION get_session_by_invite_code(uuid) TO anon, authenticated;

-- ── 5. Restore rsvp_session (without p_payment_intent_id) ────────────────────

DROP FUNCTION IF EXISTS rsvp_session(uuid, text, text, text, text);

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
  SELECT * INTO v_session
  FROM event_sessions WHERE invite_code = p_invite_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT event_type INTO v_event_type FROM events WHERE id = v_session.event_id;
  IF v_event_type <> 'signup' THEN RAISE EXCEPTION 'not_a_signup_event'; END IF;

  IF v_session.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_session.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;

  IF v_user_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM event_session_roster
               WHERE session_id = v_session.id AND user_id = v_user_id) THEN
      RAISE EXCEPTION 'already_signed_up';
    END IF;
  END IF;

  IF v_session.requires_approval THEN
    v_status := 'pending_review';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'pending_review';

    INSERT INTO event_session_roster
      (id, session_id, user_id, display_name, email, phone, status, signup_order)
    VALUES
      (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone, v_status, v_next_order);

    IF v_user_id IS NOT NULL THEN
      INSERT INTO event_guests (event_id, user_id, display_name, email, phone, status, role, rsvp_at)
      VALUES (v_session.event_id, v_user_id, p_display_name, p_email, p_phone, 'accepted', 'member', now())
      ON CONFLICT (event_id, user_id) DO UPDATE
        SET status = 'accepted'
        WHERE event_guests.status IN ('declined', 'left', 'pending');
    END IF;

    SELECT
      COUNT(*) FILTER (WHERE status = 'going'),
      COUNT(*) FILTER (WHERE status = 'waitlisted')
    INTO v_confirmed, v_waitlisted
    FROM event_session_roster WHERE session_id = v_session.id;

    RETURN QUERY SELECT
      v_roster_id, v_next_order, v_status,
      v_confirmed, v_waitlisted, v_session.capacity;
    RETURN;
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE status = 'going'),
    COUNT(*) FILTER (WHERE status = 'waitlisted')
  INTO v_confirmed, v_waitlisted
  FROM event_session_roster WHERE session_id = v_session.id;

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

  IF v_user_id IS NOT NULL THEN
    INSERT INTO event_guests (event_id, user_id, display_name, email, phone, status, role, rsvp_at)
    VALUES (v_session.event_id, v_user_id, p_display_name, p_email, p_phone, 'accepted', 'member', now())
    ON CONFLICT (event_id, user_id) DO UPDATE
      SET status = 'accepted'
      WHERE event_guests.status IN ('declined', 'left', 'pending');
  END IF;

  RETURN QUERY SELECT
    v_roster_id,
    CASE WHEN v_status = 'going'
         THEN (v_confirmed + 1)::integer
         ELSE (v_waitlisted + 1)::integer
    END,
    v_status,
    v_confirmed + CASE WHEN v_status = 'going'       THEN 1 ELSE 0 END,
    v_waitlisted + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END,
    v_session.capacity;
END;
$$;

GRANT EXECUTE ON FUNCTION rsvp_session(uuid, text, text, text) TO anon, authenticated;
