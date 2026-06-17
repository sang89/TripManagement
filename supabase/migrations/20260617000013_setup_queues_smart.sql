-- ─────────────────────────────────────────────────────────────────────────────
-- Smart setup_session_queues: keep users when increasing, kick when decreasing.
--
-- Previous behaviour: always DELETE all activities + entries, then INSERT fresh.
-- This meant even adding spots or queues wiped everyone out.
--
-- New behaviour:
--   • Increasing queue count  → INSERT new activities; existing entries intact.
--   • Decreasing queue count  → DELETE excess activities (CASCADE kicks entries).
--   • Increasing spots        → UPDATE players_per_round; existing entries intact.
--   • Decreasing spots        → UPDATE players_per_round + DELETE entries beyond
--                               the new limit (explicit kick).
--   • Changing allow_duplicates → UPDATE flag only; no entries affected.
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.setup_session_queues(uuid, integer, integer, boolean);

CREATE FUNCTION public.setup_session_queues(
  p_session_id       uuid,
  p_count            integer,
  p_spots            integer,
  p_allow_duplicates boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id      uuid;
  v_existing_cnt  integer;
  v_max_order     integer;
  i               integer;
BEGIN
  SELECT es.event_id INTO v_event_id
  FROM event_sessions es WHERE es.id = p_session_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  IF p_count < 1 OR p_count > 50 THEN RAISE EXCEPTION 'invalid_count'; END IF;
  IF p_spots < 1 OR p_spots > 20 THEN RAISE EXCEPTION 'invalid_spots'; END IF;

  SELECT COUNT(*) INTO v_existing_cnt
  FROM session_queue_activities WHERE session_id = p_session_id;

  -- ── Decreasing queue count: remove excess from the bottom ─────────────────
  IF p_count < v_existing_cnt THEN
    -- Delete the last (existing - new) activities by sort_order DESC.
    -- CASCADE removes their entries automatically.
    WITH ranked AS (
      SELECT id,
             ROW_NUMBER() OVER (ORDER BY sort_order DESC) AS rn
      FROM session_queue_activities
      WHERE session_id = p_session_id
    )
    DELETE FROM session_queue_activities
    WHERE id IN (SELECT id FROM ranked WHERE rn <= v_existing_cnt - p_count);
  END IF;

  -- ── Decreasing spots: explicitly kick entries beyond the new limit ─────────
  IF p_spots < (SELECT COALESCE(MAX(players_per_round), 0)
                FROM session_queue_activities WHERE session_id = p_session_id) THEN
    DELETE FROM session_queue_entries sqe
    USING session_queue_activities sqa
    WHERE sqe.activity_id = sqa.id
      AND sqa.session_id  = p_session_id
      AND sqe.queue_position > p_spots;
  END IF;

  -- ── Update all remaining activities (spots + flag) ─────────────────────────
  UPDATE session_queue_activities
  SET players_per_round = p_spots,
      allow_duplicates  = p_allow_duplicates
  WHERE session_id = p_session_id;

  -- ── Increasing queue count: append new activities ──────────────────────────
  IF p_count > v_existing_cnt THEN
    SELECT COALESCE(MAX(sort_order), 0) INTO v_max_order
    FROM session_queue_activities WHERE session_id = p_session_id;

    FOR i IN (v_existing_cnt + 1)..p_count LOOP
      v_max_order := v_max_order + 1;
      INSERT INTO session_queue_activities
        (event_id, session_id, name, players_per_round, allow_duplicates,
         status, sort_order, created_by)
      VALUES
        (v_event_id, p_session_id, 'Queue ' || i, p_spots, p_allow_duplicates,
         'active', v_max_order, auth.uid());
    END LOOP;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.setup_session_queues(uuid, integer, integer, boolean) TO authenticated;
