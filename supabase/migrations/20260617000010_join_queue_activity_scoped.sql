-- ─────────────────────────────────────────────────────────────────────────────
-- Change join_queue duplicate check from session-scoped to activity-scoped.
--
-- Previous behaviour: a user could only be in ONE queue across the whole
-- session.  This was too strict — the intended design allows signing up for
-- multiple queue activities in the same session (e.g. Court 1 AND Court 2).
-- The only restriction is that you cannot claim TWO SPOTS within the same
-- queue activity.
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.join_queue(uuid);

CREATE FUNCTION public.join_queue(
  p_activity_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid          uuid    := auth.uid();
  v_display_name text;
  v_avatar_url   text;
  v_session_id   uuid;
  v_event_id     uuid;
  v_spots        integer;
  v_claimed      bigint;
BEGIN
  SELECT a.session_id, es.event_id, a.players_per_round
  INTO v_session_id, v_event_id, v_spots
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'activity_not_found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests eg
    WHERE eg.event_id = v_event_id
      AND eg.user_id = v_uid
      AND eg.status NOT IN ('left', 'declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events ev WHERE ev.id = v_event_id AND ev.created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  -- One spot per activity only (not per session — users may join multiple activities).
  IF EXISTS (
    SELECT 1 FROM session_queue_entries sqe
    WHERE sqe.activity_id = p_activity_id AND sqe.user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries sqe2 WHERE sqe2.activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN
    RAISE EXCEPTION 'queue_full';
  END IF;

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
