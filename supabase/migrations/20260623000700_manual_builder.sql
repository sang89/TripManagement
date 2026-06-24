-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament customization M8 — manual builder (custom format).
--
-- A 'custom' division has no auto-generated bracket; the organizer hand-creates
-- matches (and ties) round by round. Allow 'custom' in the format CHECK and add
-- manual match CRUD RPCs.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE tournament_divisions DROP CONSTRAINT IF EXISTS tournament_divisions_format_check;
ALTER TABLE tournament_divisions
  ADD CONSTRAINT tournament_divisions_format_check
  CHECK (format IN ('round_robin', 'single_elimination', 'pools_playoff', 'custom'));

-- add_tournament_match — manually create a match (or tie) in a division.
CREATE OR REPLACE FUNCTION add_tournament_match(
  p_division_id uuid,
  p_round_number int,
  p_entrant1_id uuid DEFAULT NULL,
  p_entrant2_id uuid DEFAULT NULL,
  p_is_tie      boolean DEFAULT false
)
RETURNS SETOF tournament_matches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_division tournament_divisions%ROWTYPE;
  v_next_num int;
  v_status   text;
  v_new_id   uuid;
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_division.event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT COALESCE(MAX(match_number), 0) + 1 INTO v_next_num
  FROM tournament_matches WHERE division_id = p_division_id AND round_number = p_round_number;

  v_status := CASE WHEN p_entrant1_id IS NOT NULL AND p_entrant2_id IS NOT NULL
                   THEN 'scheduled' ELSE 'pending' END;

  INSERT INTO tournament_matches (
    division_id, bracket_type, round_number, match_number,
    entrant1_id, entrant2_id, status, is_tie
  ) VALUES (
    p_division_id, 'winners', p_round_number, v_next_num,
    p_entrant1_id, p_entrant2_id, v_status, COALESCE(p_is_tie, false)
  )
  RETURNING id INTO v_new_id;

  IF COALESCE(p_is_tie, false) THEN
    PERFORM _ensure_tie_submatches(v_new_id);
  END IF;

  -- Mark the division in progress once it has matches.
  UPDATE tournament_divisions SET status = 'in_progress'
    WHERE id = p_division_id AND status IN ('setup', 'registration');

  RETURN QUERY SELECT * FROM tournament_matches WHERE id = v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION add_tournament_match(uuid, int, uuid, uuid, boolean) TO authenticated;

-- update_tournament_match — set/clear the two sides of a manual match.
CREATE OR REPLACE FUNCTION update_tournament_match(
  p_match_id    uuid,
  p_entrant1_id uuid DEFAULT NULL,
  p_entrant2_id uuid DEFAULT NULL,
  p_clear1      boolean DEFAULT false,
  p_clear2      boolean DEFAULT false
)
RETURNS SETOF tournament_matches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match    tournament_matches%ROWTYPE;
  v_event_id uuid;
  v_e1 uuid; v_e2 uuid;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;
  SELECT d.event_id INTO v_event_id FROM tournament_divisions d WHERE d.id = v_match.division_id;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  v_e1 := CASE WHEN p_clear1 THEN NULL ELSE COALESCE(p_entrant1_id, v_match.entrant1_id) END;
  v_e2 := CASE WHEN p_clear2 THEN NULL ELSE COALESCE(p_entrant2_id, v_match.entrant2_id) END;

  UPDATE tournament_matches
    SET entrant1_id = v_e1,
        entrant2_id = v_e2,
        status = CASE
          WHEN status = 'completed' THEN status
          WHEN v_e1 IS NOT NULL AND v_e2 IS NOT NULL THEN 'scheduled'
          ELSE 'pending' END
    WHERE id = p_match_id;

  IF v_match.is_tie AND v_e1 IS NOT NULL AND v_e2 IS NOT NULL THEN
    PERFORM _ensure_tie_submatches(p_match_id);
  END IF;

  RETURN QUERY SELECT * FROM tournament_matches WHERE id = p_match_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_tournament_match(uuid, uuid, uuid, boolean, boolean) TO authenticated;

-- delete_tournament_match — remove a manual match.
CREATE OR REPLACE FUNCTION delete_tournament_match(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT d.event_id INTO v_event_id
  FROM tournament_matches m JOIN tournament_divisions d ON d.id = m.division_id
  WHERE m.id = p_match_id;
  IF v_event_id IS NULL THEN RAISE EXCEPTION 'match_not_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM tournament_matches WHERE id = p_match_id;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_tournament_match(uuid) TO authenticated;
