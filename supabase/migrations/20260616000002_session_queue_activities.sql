-- ─────────────────────────────────────────────────────────────────────────────
-- Session Queue Activities
--
-- Adds event-level in-session activity tracking, starting with "Queue Up":
--   • session_queue_activities — one per named court/queue (e.g. "Court 1")
--   • session_queue_entries    — players inside a specific queue
--   • session_free_pool        — members checked-in but not in any queue
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── 1. Tables ────────────────────────────────────────────────────────────────

CREATE TABLE session_queue_activities (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name              text        NOT NULL DEFAULT 'Queue',
  players_per_round integer     NOT NULL,
  max_rounds        integer,              -- null = no limit
  current_round     integer     NOT NULL DEFAULT 0,  -- 0 = not started yet
  status            text        NOT NULL DEFAULT 'waiting'
                                CHECK (status IN ('waiting','active','ended')),
  -- Denormalized counts maintained by trigger below.
  waiting_count     integer     NOT NULL DEFAULT 0,
  playing_count     integer     NOT NULL DEFAULT 0,
  created_by        uuid        REFERENCES auth.users(id),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_queue_activities_event
  ON session_queue_activities(event_id, created_at ASC);

CREATE TABLE session_queue_entries (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id    uuid        NOT NULL REFERENCES session_queue_activities(id) ON DELETE CASCADE,
  user_id        uuid        REFERENCES auth.users(id),
  display_name   text        NOT NULL,
  avatar_url     text,
  status         text        NOT NULL DEFAULT 'waiting'
                 CHECK (status IN ('playing','waiting')),
  queue_position integer     NOT NULL,
  rounds_played  integer     NOT NULL DEFAULT 0,
  joined_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(activity_id, user_id)
);

CREATE INDEX idx_queue_entries_activity_pos
  ON session_queue_entries(activity_id, queue_position ASC);

CREATE TABLE session_free_pool (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id       uuid        NOT NULL REFERENCES auth.users(id),
  display_name  text        NOT NULL,
  avatar_url    text,
  checked_in_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

CREATE INDEX idx_free_pool_event
  ON session_free_pool(event_id, checked_in_at ASC);

-- ─── 2. REPLICA IDENTITY + Realtime publication ────────────────────────────

ALTER TABLE session_queue_activities REPLICA IDENTITY FULL;
ALTER TABLE session_queue_entries    REPLICA IDENTITY FULL;
ALTER TABLE session_free_pool        REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE session_queue_activities;
ALTER PUBLICATION supabase_realtime ADD TABLE session_queue_entries;
ALTER PUBLICATION supabase_realtime ADD TABLE session_free_pool;

-- ─── 3. Denormalized-count trigger ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._update_queue_activity_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_activity_id uuid;
BEGIN
  v_activity_id := COALESCE(NEW.activity_id, OLD.activity_id);
  UPDATE session_queue_activities SET
    playing_count = (SELECT COUNT(*) FROM session_queue_entries
                     WHERE activity_id = v_activity_id AND status = 'playing'),
    waiting_count = (SELECT COUNT(*) FROM session_queue_entries
                     WHERE activity_id = v_activity_id AND status = 'waiting')
  WHERE id = v_activity_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_queue_entry_counts
AFTER INSERT OR UPDATE OR DELETE ON session_queue_entries
FOR EACH ROW EXECUTE FUNCTION public._update_queue_activity_counts();

-- ─── 4. RLS ───────────────────────────────────────────────────────────────

ALTER TABLE session_queue_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_queue_entries    ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_free_pool        ENABLE ROW LEVEL SECURITY;

-- session_queue_activities: organizer full access
CREATE POLICY "organizer full access on queue activities" ON session_queue_activities
  USING (
    EXISTS (SELECT 1 FROM events WHERE id = session_queue_activities.event_id AND created_by = auth.uid())
  );

-- session_queue_activities: event member read
CREATE POLICY "members read queue activities" ON session_queue_activities
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_guests
      WHERE event_id = session_queue_activities.event_id
        AND user_id  = auth.uid()
        AND status NOT IN ('left', 'declined')
    )
  );

-- session_queue_entries: organizer full access
CREATE POLICY "organizer full access on queue entries" ON session_queue_entries
  USING (
    EXISTS (
      SELECT 1 FROM session_queue_activities sqa
      JOIN events e ON e.id = sqa.event_id
      WHERE sqa.id = session_queue_entries.activity_id
        AND e.created_by = auth.uid()
    )
  );

-- session_queue_entries: event member read
CREATE POLICY "members read queue entries" ON session_queue_entries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM session_queue_activities sqa
      JOIN event_guests eg ON eg.event_id = sqa.event_id
      WHERE sqa.id  = session_queue_entries.activity_id
        AND eg.user_id = auth.uid()
        AND eg.status NOT IN ('left', 'declined')
    )
  );

-- session_free_pool: organizer full access
CREATE POLICY "organizer full access on free pool" ON session_free_pool
  USING (
    EXISTS (SELECT 1 FROM events WHERE id = session_free_pool.event_id AND created_by = auth.uid())
  );

-- session_free_pool: member read
CREATE POLICY "members read free pool" ON session_free_pool
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_guests
      WHERE event_id = session_free_pool.event_id
        AND user_id  = auth.uid()
        AND status NOT IN ('left', 'declined')
    )
  );

-- session_free_pool: own row management
CREATE POLICY "user manages own free pool entry" ON session_free_pool
  FOR ALL USING (user_id = auth.uid());

-- ─── 5. RPCs ─────────────────────────────────────────────────────────────

-- 5a. join_queue ─────────────────────────────────────────────────────────────
-- Atomically removes caller from the event free pool (if present) and adds
-- them to the back of the named queue's waiting list.
CREATE FUNCTION public.join_queue(
  p_activity_id uuid,
  p_event_id    uuid
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
  v_next_pos     integer;
  v_new_id       uuid;
BEGIN
  -- Must be a member of the event (or organizer).
  SELECT p.full_name, p.avatar_url
  INTO v_display_name, v_avatar_url
  FROM profiles p
  WHERE p.id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests
    WHERE event_id = p_event_id AND user_id = v_uid AND status NOT IN ('left', 'declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events WHERE id = p_event_id AND created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  -- Next waiting position.
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_next_pos
  FROM session_queue_entries
  WHERE activity_id = p_activity_id AND status = 'waiting';

  -- Remove from free pool if present.
  DELETE FROM session_free_pool
  WHERE event_id = p_event_id AND user_id = v_uid;

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

GRANT EXECUTE ON FUNCTION public.join_queue(uuid, uuid) TO authenticated;

-- 5b. leave_queue ────────────────────────────────────────────────────────────
-- Removes the caller (or any entry the organizer selects) from the queue.
-- Renumbers 'waiting' positions for that activity after removal.
CREATE FUNCTION public.leave_queue(
  p_entry_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_activity_id uuid;
  v_event_id    uuid;
  v_was_waiting boolean;
BEGIN
  SELECT e.activity_id, a.event_id, (e.status = 'waiting')
  INTO v_activity_id, v_event_id, v_was_waiting
  FROM session_queue_entries e
  JOIN session_queue_activities a ON a.id = e.activity_id
  WHERE e.id = p_entry_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  -- Must own the row or be the event organizer.
  IF NOT EXISTS (SELECT 1 FROM session_queue_entries WHERE id = p_entry_id AND user_id = v_uid)
  AND NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = v_uid)
  THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM session_queue_entries WHERE id = p_entry_id;

  -- Renumber remaining 'waiting' entries to close the gap.
  IF v_was_waiting THEN
    WITH numbered AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY queue_position ASC) AS new_pos
      FROM session_queue_entries
      WHERE activity_id = v_activity_id AND status = 'waiting'
    )
    UPDATE session_queue_entries ue
    SET queue_position = n.new_pos
    FROM numbered n
    WHERE ue.id = n.id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_queue(uuid) TO authenticated;

-- 5c. start_queue ────────────────────────────────────────────────────────────
-- Organizer starts the queue: promotes the first N waiting players to 'playing'
-- and sets current_round = 1, status = 'active'.
CREATE FUNCTION public.start_queue(
  p_activity_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id          uuid;
  v_players_per_round integer;
BEGIN
  SELECT a.event_id, a.players_per_round
  INTO v_event_id, v_players_per_round
  FROM session_queue_activities a
  WHERE a.id = p_activity_id AND a.status = 'waiting';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'queue_not_in_waiting_state';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  -- Promote first N waiting entries.
  UPDATE session_queue_entries SET status = 'playing'
  WHERE id IN (
    SELECT id FROM session_queue_entries
    WHERE activity_id = p_activity_id AND status = 'waiting'
    ORDER BY queue_position ASC
    LIMIT v_players_per_round
  );

  -- Renumber remaining waiting entries from 1.
  WITH numbered AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY queue_position ASC) AS new_pos
    FROM session_queue_entries
    WHERE activity_id = p_activity_id AND status = 'waiting'
  )
  UPDATE session_queue_entries e
  SET queue_position = n.new_pos
  FROM numbered n
  WHERE e.id = n.id;

  UPDATE session_queue_activities
  SET current_round = 1, status = 'active'
  WHERE id = p_activity_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_queue(uuid) TO authenticated;

-- 5d. advance_queue_round ────────────────────────────────────────────────────
-- Organizer ends the current round.
--   p_rejoin = true  → current players go to the back of the waiting queue.
--   p_rejoin = false → current players are removed (released to free pool).
-- Then the next N waiting players are promoted to 'playing'.
CREATE FUNCTION public.advance_queue_round(
  p_activity_id uuid,
  p_rejoin      boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id          uuid;
  v_players_per_round integer;
  v_current_round     integer;
  v_max_rounds        integer;
  v_new_round         integer;
  v_new_status        text;
  v_waiting_max_pos   integer;
BEGIN
  SELECT a.event_id, a.players_per_round, a.current_round, a.max_rounds
  INTO v_event_id, v_players_per_round, v_current_round, v_max_rounds
  FROM session_queue_activities a
  WHERE a.id = p_activity_id AND a.status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'queue_not_active';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  v_new_round := v_current_round + 1;

  IF p_rejoin THEN
    -- Find current max waiting position to append after.
    SELECT COALESCE(MAX(queue_position), 0)
    INTO v_waiting_max_pos
    FROM session_queue_entries
    WHERE activity_id = p_activity_id AND status = 'waiting';

    -- Move playing → waiting at end of queue.
    WITH playing_ranked AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY queue_position ASC) AS rn
      FROM session_queue_entries
      WHERE activity_id = p_activity_id AND status = 'playing'
    )
    UPDATE session_queue_entries e
    SET
      status        = 'waiting',
      rounds_played = e.rounds_played + 1,
      queue_position = v_waiting_max_pos + pr.rn::integer
    FROM playing_ranked pr
    WHERE e.id = pr.id;
  ELSE
    -- Delete playing entries (they return to free pool manually if desired).
    DELETE FROM session_queue_entries
    WHERE activity_id = p_activity_id AND status = 'playing';
  END IF;

  -- Determine new activity status.
  IF v_max_rounds IS NOT NULL AND v_new_round > v_max_rounds THEN
    v_new_status := 'ended';
  ELSE
    v_new_status := 'active';
  END IF;

  -- Promote next N waiting entries to playing (only if still active).
  IF v_new_status = 'active' THEN
    UPDATE session_queue_entries SET status = 'playing'
    WHERE id IN (
      SELECT id FROM session_queue_entries
      WHERE activity_id = p_activity_id AND status = 'waiting'
      ORDER BY queue_position ASC
      LIMIT v_players_per_round
    );
  END IF;

  -- Renumber remaining waiting entries to keep positions compact.
  WITH numbered AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY queue_position ASC) AS new_pos
    FROM session_queue_entries
    WHERE activity_id = p_activity_id AND status = 'waiting'
  )
  UPDATE session_queue_entries e
  SET queue_position = n.new_pos
  FROM numbered n
  WHERE e.id = n.id;

  -- Update the activity row.
  UPDATE session_queue_activities
  SET current_round = v_new_round, status = v_new_status
  WHERE id = p_activity_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_queue_round(uuid, boolean) TO authenticated;

-- 5e. delete_queue_activity ──────────────────────────────────────────────────
-- Organizer deletes a queue activity. CASCADE handles entries.
CREATE FUNCTION public.delete_queue_activity(
  p_activity_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT event_id INTO v_event_id
  FROM session_queue_activities
  WHERE id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  DELETE FROM session_queue_activities WHERE id = p_activity_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_queue_activity(uuid) TO authenticated;
