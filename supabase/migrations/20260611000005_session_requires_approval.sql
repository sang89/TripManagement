-- "Need Review" flag on sessions.
-- When requires_approval = true, new signups land in 'pending_review' state
-- and must be approved by the organizer before they count as confirmed.

-- ── 1. Add column to event_sessions ──────────────────────────────────────────

ALTER TABLE event_sessions
  ADD COLUMN IF NOT EXISTS requires_approval boolean NOT NULL DEFAULT false;

-- ── 2. Extend event_session_roster status to include pending_review ───────────

ALTER TABLE event_session_roster
  DROP CONSTRAINT IF EXISTS event_session_roster_status_check;

ALTER TABLE event_session_roster
  ADD CONSTRAINT event_session_roster_status_check
  CHECK (status IN ('going', 'waitlisted', 'pending_review'));

-- ── 3. Update add_event_session to accept p_requires_approval ────────────────

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

-- ── 4. Update rsvp_session to honour requires_approval ───────────────────────

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

  -- When requires_approval = true, new requests go to 'pending_review'.
  IF v_session.requires_approval THEN
    v_status := 'pending_review';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'pending_review';

    INSERT INTO event_session_roster
      (id, session_id, user_id, display_name, email, phone, status, signup_order)
    VALUES
      (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone, v_status, v_next_order);

    -- Auto-join event for authenticated users so it shows in their list.
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

  -- Normal flow (no approval required).
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

-- ── 5. Organizer approve / reject RPCs ───────────────────────────────────────

CREATE OR REPLACE FUNCTION session_approve_request(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry   event_session_roster%ROWTYPE;
  v_session event_sessions%ROWTYPE;
  v_next_order integer;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  IF v_entry.status <> 'pending_review' THEN RAISE EXCEPTION 'not_pending'; END IF;

  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;

  -- Verify caller is the organizer.
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_session.event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
  FROM event_session_roster
  WHERE session_id = v_entry.session_id AND status = 'going';

  UPDATE event_session_roster
  SET status = 'going', signup_order = v_next_order
  WHERE id = p_roster_id;
END;
$$;

GRANT EXECUTE ON FUNCTION session_approve_request(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION session_reject_request(p_roster_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry   event_session_roster%ROWTYPE;
  v_session event_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;

  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_session.event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  DELETE FROM event_session_roster WHERE id = p_roster_id;
END;
$$;

GRANT EXECUTE ON FUNCTION session_reject_request(uuid) TO authenticated;
