-- ─────────────────────────────────────────────────────────────────────────────
-- Fix join_queue: add FOR UPDATE row lock + use MAX(queue_position)+1
--
-- Two race-condition bugs fixed here:
--
-- 1. No row lock: two concurrent callers could both read COUNT=3 (for a 4-spot
--    queue), both pass the capacity check, and both INSERT — overbooking the
--    queue by one entry. Fix: lock the activity row with FOR UPDATE so concurrent
--    joins queue up behind each other. Mirrors the pattern in add_members_to_queue.
--
-- 2. COUNT used for position: after a leave, positions have gaps
--    (e.g. 1, 3, 4). A new join computed COUNT=3 and inserted queue_position=4,
--    colliding with the existing entry at position 4. Fix: use
--    COALESCE(MAX(queue_position), 0) + 1 for position assignment while still
--    using COUNT for the capacity check.
-- ─────────────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.join_queue(uuid);

CREATE FUNCTION public.join_queue(p_activity_id uuid)
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
  v_max_pos      integer;
BEGIN
  -- Lock the activity row so concurrent joins for the same activity serialize.
  -- Any other join_queue call for this activity will block here until this
  -- transaction commits — preventing both overbooking and position collisions.
  SELECT a.session_id, es.event_id, a.players_per_round
  INTO v_session_id, v_event_id, v_spots
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id
  FOR UPDATE;

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

  -- Duplicate check: one spot per activity.
  IF EXISTS (
    SELECT 1 FROM session_queue_entries sqe
    WHERE sqe.activity_id = p_activity_id AND sqe.user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  -- Capacity check uses COUNT (unaffected by position gaps).
  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries sqe2 WHERE sqe2.activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN
    RAISE EXCEPTION 'queue_full';
  END IF;

  -- Position uses MAX+1 to avoid duplicate values when gaps exist after leaves.
  SELECT COALESCE(MAX(queue_position), 0) INTO v_max_pos
  FROM session_queue_entries WHERE activity_id = p_activity_id;

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
    (p_activity_id, v_uid, v_display_name, v_avatar_url, 'playing', v_max_pos + 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_queue(uuid) TO authenticated;
