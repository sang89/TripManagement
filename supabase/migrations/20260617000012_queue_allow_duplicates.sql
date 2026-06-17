-- ─────────────────────────────────────────────────────────────────────────────
-- Queue allow_duplicates flag
--
-- When false (default): a user may only be in ONE queue activity per session.
-- When true: a user may join multiple queue activities in the same session.
--
-- The flag lives on session_queue_activities so join_queue can read it in a
-- single row lookup without an extra table join.  All activities in a session
-- share the same value — setup_session_queues sets it uniformly on creation.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE session_queue_activities
  ADD COLUMN IF NOT EXISTS allow_duplicates boolean NOT NULL DEFAULT false;

-- ── Update setup_session_queues to accept the flag ───────────────────────────
DROP FUNCTION IF EXISTS public.setup_session_queues(uuid, integer, integer);

CREATE FUNCTION public.setup_session_queues(
  p_session_id       uuid,
  p_count            integer,
  p_spots            integer,
  p_allow_duplicates boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id uuid;
  i          integer;
BEGIN
  SELECT es.event_id INTO v_event_id
  FROM event_sessions es WHERE es.id = p_session_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  IF p_count < 1 OR p_count > 50 THEN RAISE EXCEPTION 'invalid_count'; END IF;
  IF p_spots < 1 OR p_spots > 20 THEN RAISE EXCEPTION 'invalid_spots'; END IF;

  DELETE FROM session_queue_activities WHERE session_id = p_session_id;

  FOR i IN 1..p_count LOOP
    INSERT INTO session_queue_activities
      (event_id, session_id, name, players_per_round, allow_duplicates, status, sort_order, created_by)
    VALUES
      (v_event_id, p_session_id, 'Queue ' || i, p_spots, p_allow_duplicates, 'active', i, auth.uid());
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.setup_session_queues(uuid, integer, integer, boolean) TO authenticated;

-- ── Update join_queue to enforce the flag ────────────────────────────────────
DROP FUNCTION IF EXISTS public.join_queue(uuid);

CREATE FUNCTION public.join_queue(
  p_activity_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid              uuid    := auth.uid();
  v_display_name     text;
  v_avatar_url       text;
  v_session_id       uuid;
  v_event_id         uuid;
  v_spots            integer;
  v_claimed          bigint;
  v_allow_duplicates boolean;
BEGIN
  SELECT a.session_id, es.event_id, a.players_per_round, a.allow_duplicates
  INTO v_session_id, v_event_id, v_spots, v_allow_duplicates
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'activity_not_found'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests eg
    WHERE eg.event_id = v_event_id AND eg.user_id = v_uid AND eg.status NOT IN ('left','declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events ev WHERE ev.id = v_event_id AND ev.created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  -- Always block a second spot in the same activity.
  IF EXISTS (
    SELECT 1 FROM session_queue_entries WHERE activity_id = p_activity_id AND user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  -- When duplicates are NOT allowed, also block if user is already in any other
  -- activity within this session.
  IF NOT v_allow_duplicates AND EXISTS (
    SELECT 1 FROM session_queue_entries sqe
    JOIN session_queue_activities sqa ON sqa.id = sqe.activity_id
    WHERE sqa.session_id = v_session_id
      AND sqe.user_id = v_uid
      AND sqe.activity_id <> p_activity_id
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries WHERE activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN RAISE EXCEPTION 'queue_full'; END IF;

  SELECT
    COALESCE(NULLIF(TRIM(up.full_name), ''), split_part(au.email, '@', 1), 'Player'),
    up.trip_avatar_url
  INTO v_display_name, v_avatar_url
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = v_uid;

  INSERT INTO session_queue_entries
    (activity_id, user_id, display_name, avatar_url, status, queue_position)
  VALUES
    (p_activity_id, v_uid, v_display_name, v_avatar_url, 'playing', (v_claimed + 1)::integer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_queue(uuid) TO authenticated;

-- ── Update add_member_to_queue to enforce the flag ───────────────────────────
DROP FUNCTION IF EXISTS public.add_member_to_queue(uuid, uuid, text, text);

CREATE FUNCTION public.add_member_to_queue(
  p_activity_id  uuid,
  p_user_id      uuid,
  p_display_name text,
  p_avatar_url   text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid              uuid    := auth.uid();
  v_event_id         uuid;
  v_session_id       uuid;
  v_spots            integer;
  v_claimed          bigint;
  v_allow_duplicates boolean;
BEGIN
  SELECT es.event_id, a.session_id, a.players_per_round, a.allow_duplicates
  INTO v_event_id, v_session_id, v_spots, v_allow_duplicates
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'activity_not_found'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests eg
    WHERE eg.event_id = v_event_id AND eg.user_id = v_uid AND eg.status NOT IN ('left','declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events ev WHERE ev.id = v_event_id AND ev.created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  IF p_user_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM session_queue_entries WHERE activity_id = p_activity_id AND user_id = p_user_id
    ) THEN
      RAISE EXCEPTION 'already_in_queue';
    END IF;

    IF NOT v_allow_duplicates AND EXISTS (
      SELECT 1 FROM session_queue_entries sqe
      JOIN session_queue_activities sqa ON sqa.id = sqe.activity_id
      WHERE sqa.session_id = v_session_id
        AND sqe.user_id = p_user_id
        AND sqe.activity_id <> p_activity_id
    ) THEN
      RAISE EXCEPTION 'already_in_queue';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries WHERE activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN RAISE EXCEPTION 'queue_full'; END IF;

  INSERT INTO session_queue_entries
    (activity_id, user_id, display_name, avatar_url, status, queue_position)
  VALUES
    (p_activity_id, p_user_id,
     COALESCE(NULLIF(TRIM(p_display_name), ''), 'Guest'),
     p_avatar_url, 'playing', (v_claimed + 1)::integer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_member_to_queue(uuid, uuid, text, text) TO authenticated;
