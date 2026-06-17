-- ─────────────────────────────────────────────────────────────────────────────
-- Scope queue activities and free pool to a specific event_session.
--
-- Multiple sessions can run in parallel for the same signup event.
-- Activities (queues, free pool) now belong to one session, not just the event.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add session_id to session_queue_activities
ALTER TABLE session_queue_activities
  ADD COLUMN session_id uuid NOT NULL REFERENCES event_sessions(id) ON DELETE CASCADE;

CREATE INDEX idx_queue_activities_session
  ON session_queue_activities(session_id, created_at ASC);

-- 2. Add session_id to session_free_pool, replace UNIQUE constraint
ALTER TABLE session_free_pool
  ADD COLUMN session_id uuid NOT NULL REFERENCES event_sessions(id) ON DELETE CASCADE;

ALTER TABLE session_free_pool
  DROP CONSTRAINT session_free_pool_event_id_user_id_key;

ALTER TABLE session_free_pool
  ADD CONSTRAINT session_free_pool_session_user_unique UNIQUE(session_id, user_id);

CREATE INDEX idx_free_pool_session
  ON session_free_pool(session_id, checked_in_at ASC);

-- 3. Re-create join_queue to remove p_event_id (derive it from the activity/session)
DROP FUNCTION IF EXISTS public.join_queue(uuid, uuid);

CREATE FUNCTION public.join_queue(
  p_activity_id uuid
)
RETURNS TABLE(
  id             uuid,
  activity_id    uuid,
  user_id        uuid,
  display_name   text,
  avatar_url     text,
  status         text,
  queue_position integer,
  rounds_played  integer,
  joined_at      timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_display_name text;
  v_avatar_url   text;
  v_session_id   uuid;
  v_event_id     uuid;
  v_next_pos     integer;
  v_new_id       uuid;
BEGIN
  -- Resolve session_id and event_id from activity.
  SELECT a.session_id, es.event_id
  INTO v_session_id, v_event_id
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'activity_not_found';
  END IF;

  -- Must be a member of the event (or organizer).
  IF NOT EXISTS (
    SELECT 1 FROM event_guests
    WHERE event_id = v_event_id AND user_id = v_uid AND status NOT IN ('left', 'declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_event_id AND created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  -- Get the caller's display_name and avatar_url from their profile.
  SELECT p.full_name, p.avatar_url
  INTO v_display_name, v_avatar_url
  FROM profiles p
  WHERE p.id = v_uid;

  -- Next waiting position.
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_next_pos
  FROM session_queue_entries
  WHERE activity_id = p_activity_id AND status = 'waiting';

  -- Remove from free pool for this session (if present).
  DELETE FROM session_free_pool
  WHERE session_id = v_session_id AND user_id = v_uid;

  -- Insert entry; UNIQUE(activity_id, user_id) catches duplicate joins.
  INSERT INTO session_queue_entries
    (activity_id, user_id, display_name, avatar_url, status, queue_position)
  VALUES
    (p_activity_id, v_uid, COALESCE(v_display_name, 'Player'), v_avatar_url, 'waiting', v_next_pos)
  RETURNING session_queue_entries.id INTO v_new_id;

  RETURN QUERY
  SELECT e.id, e.activity_id, e.user_id, e.display_name, e.avatar_url,
         e.status, e.queue_position, e.rounds_played, e.joined_at
  FROM session_queue_entries e
  WHERE e.id = v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_queue(uuid) TO authenticated;
