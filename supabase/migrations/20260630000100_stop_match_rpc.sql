-- ─────────────────────────────────────────────────────────────────────────────
-- stop_match RPC
--
-- Resets an in-progress match back to 'scheduled' and clears started_at.
-- Keeps the match assigned to its court (court_id and scheduled_order are
-- unchanged); the court retains its current_match_id and in_use status so
-- the queue stays intact.  If started_at being cleared would violate the
-- time-order constraint the function still succeeds because NULL is always
-- accepted in that CHECK.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION stop_match(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match    tournament_matches%ROWTYPE;
  v_event_id uuid;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM tournament_divisions d JOIN events e ON e.id = d.event_id
  WHERE d.id = v_match.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_match.status <> 'in_progress' THEN
    RAISE EXCEPTION 'match_not_in_progress';
  END IF;

  UPDATE tournament_matches
    SET status = 'scheduled', started_at = NULL
    WHERE id = p_match_id;
END;
$$;

GRANT EXECUTE ON FUNCTION stop_match(uuid) TO authenticated;
