-- Fix FIFO ordering in rsvp_session.
--
-- Root cause: v_next_order was computed as COALESCE(MAX(signup_order), 0) + 1
-- across ALL entries (going + waitlisted).  If any going entries have NULL
-- signup_order (migrated/test data), MAX returns NULL and every new waitlisted
-- joiner gets order = 1, appearing at the top of the queue.
--
-- Fix 1 – separate order sequences per status:
--   going    → MAX(going    signup_order) + 1
--   waitlist → MAX(waitlisted signup_order) + 1
--
-- Fix 2 – signup_position now returns the human-readable RANK in the group
--   (waitlist rank 1, 2, 3 …) rather than the raw signup_order value.
--
-- Fix 3 – backfill: reindex existing going and waitlisted rows to separate
--   1-indexed sequences based on their current signup_order (already fixed by
--   the previous migration to reflect signed_up_at order).

-- Step 1: reindex going entries to 1..n within each session
WITH reordered AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY session_id
           ORDER BY signup_order ASC NULLS LAST, signed_up_at ASC, id ASC
         ) AS new_order
  FROM event_session_roster
  WHERE status = 'going'
)
UPDATE event_session_roster esr
SET    signup_order = r.new_order
FROM   reordered r
WHERE  esr.id = r.id;

-- Step 2: reindex waitlisted entries to 1..m within each session
WITH reordered AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY session_id
           ORDER BY signup_order ASC NULLS LAST, signed_up_at ASC, id ASC
         ) AS new_order
  FROM event_session_roster
  WHERE status = 'waitlisted'
)
UPDATE event_session_roster esr
SET    signup_order = r.new_order
FROM   reordered r
WHERE  esr.id = r.id;

-- Step 3: replace rsvp_session with the corrected version
CREATE OR REPLACE FUNCTION rsvp_session(
  p_invite_code  uuid,
  p_display_name text,
  p_email        text DEFAULT NULL,
  p_phone        text DEFAULT NULL
)
RETURNS TABLE(
  roster_id        uuid,
  signup_position  integer,   -- human-readable rank (1 = first in group)
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
    COUNT(*) FILTER (WHERE status = 'waitlisted')
  INTO v_confirmed, v_waitlisted
  FROM event_session_roster WHERE session_id = v_session.id;

  IF v_event.capacity IS NULL OR v_confirmed < v_event.capacity THEN
    v_status := 'going';
    -- Order within the 'going' group only
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'going';
  ELSIF v_event.waitlist_enabled THEN
    v_status := 'waitlisted';
    -- Order within the 'waitlisted' group only — guarantees FIFO regardless
    -- of whether going entries have gaps, NULLs, or were reordered.
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
    -- Return human-readable rank (1 = first in their group)
    CASE WHEN v_status = 'going'
         THEN (v_confirmed + 1)::integer
         ELSE (v_waitlisted + 1)::integer
    END,
    v_status,
    v_confirmed + CASE WHEN v_status = 'going'    THEN 1 ELSE 0 END,
    v_waitlisted + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END,
    v_event.capacity;
END;
$$;

GRANT EXECUTE ON FUNCTION rsvp_session(uuid, text, text, text) TO anon, authenticated;
