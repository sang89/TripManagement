-- ─────────────────────────────────────────────────────────────────────────────
-- Fix join_queue to store trip_avatar_url instead of avatar_url.
--
-- Previously the RPC read user_profiles.avatar_url (the PropertyManagement
-- shared avatar) when inserting a row into session_queue_entries. This caused
-- the queue spot circle to show the PropertyManagement avatar while every
-- other place in TripManagement (free pool, profile screen) shows the
-- trip-specific avatar.
--
-- Also backfills existing queue entries: where the user has a trip_avatar_url
-- set, update the stored avatar_url in session_queue_entries to match.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Backfill existing entries ────────────────────────────────────────────────
UPDATE session_queue_entries sqe
SET    avatar_url = up.trip_avatar_url
FROM   user_profiles up
WHERE  sqe.user_id = up.user_id
  AND  up.trip_avatar_url IS NOT NULL
  AND  up.trip_avatar_url <> '';

-- 2. Re-create join_queue reading trip_avatar_url ─────────────────────────────
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

  -- Must be an event member or organizer.
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

  -- User may only be in one queue per session.
  IF EXISTS (
    SELECT 1 FROM session_queue_entries sqe
    JOIN session_queue_activities sqa ON sqa.id = sqe.activity_id
    WHERE sqa.session_id = v_session_id AND sqe.user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  -- Queue must have open spots.
  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries sqe2 WHERE sqe2.activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN
    RAISE EXCEPTION 'queue_full';
  END IF;

  SELECT up.full_name, up.trip_avatar_url
  INTO v_display_name, v_avatar_url
  FROM user_profiles up WHERE up.user_id = v_uid;

  INSERT INTO session_queue_entries
    (activity_id, user_id, display_name, avatar_url, status, queue_position)
  VALUES
    (p_activity_id, v_uid,
     COALESCE(NULLIF(TRIM(v_display_name), ''), 'Member'),
     v_avatar_url, 'playing', (v_claimed + 1)::integer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_queue(uuid) TO authenticated;
