-- ─────────────────────────────────────────────────────────────────────────────
-- Court assignment (M5)
--
-- A match is assigned to a court by setting court_id + scheduled_order (its
-- position in that court's queue). The first non-completed match on a court is
-- "on court now"; the rest are "next up". record_match_score already frees the
-- court when a match completes.
-- ─────────────────────────────────────────────────────────────────────────────

-- assign_match_to_court — append a ready match to a court's queue.
CREATE OR REPLACE FUNCTION assign_match_to_court(
  p_match_id uuid,
  p_court_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match    tournament_matches%ROWTYPE;
  v_event_id uuid;
  v_court_event uuid;
  v_next_ord int;
  v_has_current boolean;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM tournament_divisions d JOIN events e ON e.id = d.event_id
  WHERE d.id = v_match.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Court must belong to the same event.
  SELECT event_id INTO v_court_event FROM tournament_courts WHERE id = p_court_id;
  IF v_court_event IS DISTINCT FROM v_event_id THEN
    RAISE EXCEPTION 'court_event_mismatch';
  END IF;

  IF v_match.status IN ('completed', 'bye') THEN
    RAISE EXCEPTION 'match_not_assignable';
  END IF;

  SELECT COALESCE(MAX(scheduled_order), 0) + 1 INTO v_next_ord
  FROM tournament_matches
  WHERE court_id = p_court_id AND status <> 'completed';

  UPDATE tournament_matches
    SET court_id = p_court_id, scheduled_order = v_next_ord
    WHERE id = p_match_id;

  -- If the court has no current match, this becomes current + court is in use.
  SELECT current_match_id IS NOT NULL INTO v_has_current
  FROM tournament_courts WHERE id = p_court_id;
  IF NOT v_has_current THEN
    UPDATE tournament_courts
      SET current_match_id = p_match_id, status = 'in_use'
      WHERE id = p_court_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION assign_match_to_court(uuid, uuid) TO authenticated;

-- unassign_match_from_court — remove a match from its court's queue.
CREATE OR REPLACE FUNCTION unassign_match_from_court(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match    tournament_matches%ROWTYPE;
  v_event_id uuid;
  v_next     uuid;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM tournament_divisions d JOIN events e ON e.id = d.event_id
  WHERE d.id = v_match.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_match.court_id IS NULL THEN RETURN; END IF;

  UPDATE tournament_matches
    SET court_id = NULL, scheduled_order = NULL
    WHERE id = p_match_id;

  -- If this was the court's current match, promote the next queued match.
  IF EXISTS (SELECT 1 FROM tournament_courts WHERE id = v_match.court_id AND current_match_id = p_match_id) THEN
    SELECT id INTO v_next
    FROM tournament_matches
    WHERE court_id = v_match.court_id AND status <> 'completed'
    ORDER BY scheduled_order NULLS LAST
    LIMIT 1;

    UPDATE tournament_courts
      SET current_match_id = v_next,
          status = CASE WHEN v_next IS NULL THEN 'available' ELSE 'in_use' END
      WHERE id = v_match.court_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION unassign_match_from_court(uuid) TO authenticated;

-- reorder_court_queue — set scheduled_order from an ordered array of match ids.
CREATE OR REPLACE FUNCTION reorder_court_queue(
  p_court_id  uuid,
  p_match_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
  v_id       uuid;
  v_ord      int := 1;
BEGIN
  SELECT event_id INTO v_event_id FROM tournament_courts WHERE id = p_court_id;
  IF v_event_id IS NULL THEN RAISE EXCEPTION 'court_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  FOREACH v_id IN ARRAY p_match_ids LOOP
    UPDATE tournament_matches
      SET scheduled_order = v_ord
      WHERE id = v_id AND court_id = p_court_id;
    v_ord := v_ord + 1;
  END LOOP;

  -- Current match = lowest-order non-completed match on the court.
  UPDATE tournament_courts c
    SET current_match_id = (
      SELECT m.id FROM tournament_matches m
      WHERE m.court_id = p_court_id AND m.status <> 'completed'
      ORDER BY m.scheduled_order NULLS LAST
      LIMIT 1
    )
    WHERE c.id = p_court_id;
END;
$$;

GRANT EXECUTE ON FUNCTION reorder_court_queue(uuid, uuid[]) TO authenticated;
