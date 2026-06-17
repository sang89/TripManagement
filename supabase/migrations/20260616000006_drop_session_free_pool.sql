-- ─────────────────────────────────────────────────────────────────────────────
-- Remove session_free_pool.
--
-- The free pool is now computed client-side:
--   free pool = session roster (status='going') minus players in any queue.
-- No separate table needed.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'session_free_pool'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime DROP TABLE session_free_pool';
  END IF;
END $$;
DROP TABLE IF EXISTS session_free_pool CASCADE;

-- Re-create join_queue without the free pool deletion.
DROP FUNCTION IF EXISTS public.join_queue(uuid);

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
  SELECT a.session_id, es.event_id
  INTO v_session_id, v_event_id
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'activity_not_found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests
    WHERE event_id = v_event_id AND user_id = v_uid AND status NOT IN ('left', 'declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_event_id AND created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  SELECT p.full_name, p.avatar_url
  INTO v_display_name, v_avatar_url
  FROM profiles p WHERE p.id = v_uid;

  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_next_pos
  FROM session_queue_entries
  WHERE activity_id = p_activity_id AND status = 'waiting';

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
