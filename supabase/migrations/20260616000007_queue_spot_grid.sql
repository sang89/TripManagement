-- ─────────────────────────────────────────────────────────────────────────────
-- Queue Spot Grid Redesign
--
-- Replaces the FIFO round-based queue with a self-service spot-claiming grid:
--   • Organizer defines N queues × M spots via setup_session_queues()
--   • UI shows rows of circles; users tap empty circles to claim spots
--   • Organizer clears a queue row (game started) → row rotates to bottom
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add sort_order to session_queue_activities
-- ─────────────────────────────────────────────
ALTER TABLE session_queue_activities
  ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_queue_activities_session_order
  ON session_queue_activities(session_id, sort_order ASC);

-- 2. RPC: setup_session_queues
-- ─────────────────────────────────────────────
-- Organizer bulk-creates N queues with M spots each.
-- Deletes existing queues for the session first (CASCADE handles entries).
DROP FUNCTION IF EXISTS public.setup_session_queues(uuid, integer, integer);

CREATE FUNCTION public.setup_session_queues(
  p_session_id uuid,
  p_count       integer,
  p_spots       integer
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id uuid;
  i          integer;
BEGIN
  SELECT es.event_id INTO v_event_id
  FROM event_sessions es WHERE es.id = p_session_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  IF p_count < 1 OR p_count > 50 THEN
    RAISE EXCEPTION 'invalid_count';
  END IF;

  IF p_spots < 1 OR p_spots > 20 THEN
    RAISE EXCEPTION 'invalid_spots';
  END IF;

  -- Delete all existing queue activities for this session (entries cascade).
  DELETE FROM session_queue_activities WHERE session_id = p_session_id;

  -- Bulk insert N queues.
  FOR i IN 1..p_count LOOP
    INSERT INTO session_queue_activities
      (event_id, session_id, name, players_per_round, status, sort_order, created_by)
    VALUES
      (v_event_id, p_session_id, 'Queue ' || i, p_spots, 'active', i, auth.uid());
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.setup_session_queues(uuid, integer, integer) TO authenticated;

-- 3. RPC: clear_queue
-- ─────────────────────────────────────────────
-- Organizer clears all entries from a queue row (game has started).
-- The cleared queue rotates to the bottom (sort_order = MAX + 1).
DROP FUNCTION IF EXISTS public.clear_queue(uuid);

CREATE FUNCTION public.clear_queue(
  p_activity_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id   uuid;
  v_session_id uuid;
  v_max_order  integer;
BEGIN
  SELECT a.event_id, a.session_id
  INTO v_event_id, v_session_id
  FROM session_queue_activities a WHERE a.id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'activity_not_found';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  -- Remove all claimed spots.
  DELETE FROM session_queue_entries WHERE activity_id = p_activity_id;

  -- Rotate to bottom: sort_order = current max + 1.
  SELECT COALESCE(MAX(sort_order), 0) + 1
  INTO v_max_order
  FROM session_queue_activities
  WHERE session_id = v_session_id;

  UPDATE session_queue_activities
  SET sort_order = v_max_order
  WHERE id = p_activity_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_queue(uuid) TO authenticated;

-- 4. Update join_queue to enforce per-session single-queue constraint and capacity
-- ─────────────────────────────────────────────────────────────────────────────
-- Returns void (Dart ignores the return value; fetchSessionQueues re-loads data).
-- Avoids RETURNS TABLE column names shadowing same-named table columns (PG 42702).
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

  SELECT up.full_name, up.avatar_url
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
