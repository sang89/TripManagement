-- B3: Use the denormalized going_count / waitlist_count from the already-locked
-- event_sessions row instead of re-counting event_session_roster.
--
-- rsvp_session does SELECT ... FOR UPDATE on event_sessions, serialising all
-- concurrent signups for the same session. Using v_session.going_count (from
-- that locked row) instead of a fresh COUNT(*) on event_session_roster
-- eliminates the TOCTOU window where two concurrent calls both passed the
-- capacity check before either insert updated the count.

CREATE OR REPLACE FUNCTION public.rsvp_session(
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
  v_next_order   integer;
  v_status       text;
  v_roster_id    uuid := gen_random_uuid();
  v_user_id      uuid := auth.uid();
BEGIN
  -- B13: require authentication — anon callers are rate-limited via the
  -- signup_rate_limits table checked separately; completely anonymous callers
  -- with no JWT at all are rejected here.
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth_required';
  END IF;

  -- Lock the session row — serialises all concurrent signups for this session.
  SELECT * INTO v_session
  FROM event_sessions WHERE invite_code = p_invite_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT event_type,
         (created_by = v_user_id)
    INTO v_event_type, v_is_organizer
  FROM events WHERE id = v_session.event_id;

  IF v_event_type <> 'signup' THEN RAISE EXCEPTION 'not_a_signup_event'; END IF;

  -- Signup lock (organizer bypasses).
  IF NOT v_is_organizer AND v_session.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_session.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;

  -- Duplicate check (backed by uq_session_roster_user partial unique index).
  IF EXISTS (
    SELECT 1 FROM event_session_roster
    WHERE session_id = v_session.id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'already_signed_up';
  END IF;

  -- Organizer always gets auto-approved; others go through requires_approval gate.
  IF v_session.requires_approval AND NOT v_is_organizer THEN
    v_status := 'pending_review';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'pending_review';

    INSERT INTO event_session_roster
      (id, session_id, user_id, display_name, email, phone, status, signup_order)
    VALUES
      (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone, v_status, v_next_order);

    INSERT INTO event_guests (event_id, user_id, display_name, email, phone, status, role, rsvp_at)
    VALUES (v_session.event_id, v_user_id, p_display_name, p_email, p_phone, 'accepted', 'member', now())
    ON CONFLICT (event_id, user_id) DO UPDATE
      SET status = 'accepted'
      WHERE event_guests.status IN ('declined', 'left', 'pending');

    -- Return denormalized counts from the locked row (authoritative after FOR UPDATE).
    RETURN QUERY SELECT
      v_roster_id, v_next_order, v_status,
      v_session.going_count::bigint,
      v_session.waitlist_count::bigint,
      v_session.capacity;
    RETURN;
  END IF;

  -- B3 fix: read capacity decision from the locked v_session row — not from a
  -- fresh COUNT(*) that could race with another concurrent transaction.
  IF v_session.capacity IS NULL OR v_session.going_count < v_session.capacity THEN
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

  INSERT INTO event_guests (event_id, user_id, display_name, email, phone, status, role, rsvp_at)
  VALUES (v_session.event_id, v_user_id, p_display_name, p_email, p_phone, 'accepted', 'member', now())
  ON CONFLICT (event_id, user_id) DO UPDATE
    SET status = 'accepted'
    WHERE event_guests.status IN ('declined', 'left', 'pending');

  RETURN QUERY SELECT
    v_roster_id,
    v_next_order,
    v_status,
    (v_session.going_count    + CASE WHEN v_status = 'going'      THEN 1 ELSE 0 END)::bigint,
    (v_session.waitlist_count + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END)::bigint,
    v_session.capacity;
END;
$$;

-- B13: authenticated users only; anon access removed.
REVOKE EXECUTE ON FUNCTION public.rsvp_session(uuid, text, text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.rsvp_session(uuid, text, text, text) TO authenticated;
