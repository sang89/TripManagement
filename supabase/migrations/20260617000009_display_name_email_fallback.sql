-- ─────────────────────────────────────────────────────────────────────────────
-- Use email-prefix as display-name fallback instead of 'Member'.
--
-- When a user's full_name is empty (e.g. new TripManagement-only signups
-- before the app started seeding full_name on registration), every place
-- that shows their name should fall back to the email prefix rather than
-- the generic string 'Member'.
--
-- Changes:
--   1. join_queue — joins auth.users to get email; uses COALESCE fallback
--   2. get_trip_profile_names — same COALESCE pattern as find_users_by_contacts
--   3. Backfill session_queue_entries rows already stuck with 'Member'
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Backfill existing 'Member' rows in session_queue_entries ─────────────────
UPDATE session_queue_entries sqe
SET    display_name = split_part(au.email, '@', 1)
FROM   auth.users au
WHERE  sqe.user_id = au.id
  AND  TRIM(sqe.display_name) = 'Member';

-- 2. Re-create join_queue with email-prefix fallback ──────────────────────────
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

  IF EXISTS (
    SELECT 1 FROM session_queue_entries sqe
    JOIN session_queue_activities sqa ON sqa.id = sqe.activity_id
    WHERE sqa.session_id = v_session_id AND sqe.user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries sqe2 WHERE sqe2.activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN
    RAISE EXCEPTION 'queue_full';
  END IF;

  -- Use email prefix as fallback when full_name is empty.
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

-- 3. Re-create get_trip_profile_names with email-prefix fallback ──────────────
CREATE OR REPLACE FUNCTION public.get_trip_profile_names(p_user_ids uuid[])
RETURNS TABLE(
  user_id    uuid,
  full_name  text,
  email      text,
  phone      text,
  avatar_url text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT
    up.user_id,
    COALESCE(NULLIF(TRIM(up.full_name), ''), split_part(au.email, '@', 1)) AS full_name,
    au.email,
    up.phone,
    up.trip_avatar_url AS avatar_url
  FROM public.user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;

GRANT EXECUTE ON FUNCTION public.get_trip_profile_names(uuid[]) TO authenticated;
