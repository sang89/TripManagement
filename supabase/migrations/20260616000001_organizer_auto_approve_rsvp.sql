-- Organizer signing up for their own session is auto-approved even when
-- requires_approval = true. They bypass the pending_review path entirely.

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
  v_session      event_sessions%ROWTYPE;
  v_event_type   event_type;
  v_is_organizer boolean := false;
  v_confirmed    bigint;
  v_waitlisted   bigint;
  v_next_order   integer;
  v_status       text;
  v_roster_id    uuid := gen_random_uuid();
  v_user_id      uuid := auth.uid();
BEGIN
  SELECT * INTO v_session
  FROM event_sessions WHERE invite_code = p_invite_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT event_type,
         (created_by = v_user_id)
    INTO v_event_type, v_is_organizer
  FROM events WHERE id = v_session.event_id;

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

  -- Organizer always gets auto-approved; other users go through requires_approval gate.
  IF v_session.requires_approval AND NOT v_is_organizer THEN
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
    v_confirmed + CASE WHEN v_status = 'going'      THEN 1 ELSE 0 END,
    v_waitlisted + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END,
    v_session.capacity;
END;
$$;

GRANT EXECUTE ON FUNCTION rsvp_session(uuid, text, text, text) TO anon, authenticated;
