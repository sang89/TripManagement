-- ─────────────────────────────────────────────────────────────────────────────
-- M7 — sub-match scoring + tie auto-advance, and team-aware bracket generation.
-- ─────────────────────────────────────────────────────────────────────────────

-- record_submatch_score — score one sub-match of a tie; recompute the tie
-- winner; on decision, complete the parent tie + auto-advance the winner.
--   p_games — array of { side1_score, side2_score }
CREATE OR REPLACE FUNCTION record_submatch_score(
  p_submatch_id uuid,
  p_games       jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sub       tournament_tie_submatches%ROWTYPE;
  v_tie       tournament_matches%ROWTYPE;
  v_div       tournament_divisions%ROWTYPE;
  v_event_id  uuid;
  v_elem      jsonb;
  v_s1        int;
  v_s2        int;
  v_g1        int := 0;
  v_g2        int := 0;
  v_win_thr   int;
  v_side1_wins int;
  v_side2_wins int;
  v_tie_winner uuid;
BEGIN
  SELECT * INTO v_sub FROM tournament_tie_submatches WHERE id = p_submatch_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'submatch_not_found'; END IF;

  SELECT * INTO v_tie FROM tournament_matches WHERE id = v_sub.tie_match_id;
  SELECT * INTO v_div FROM tournament_divisions WHERE id = v_tie.division_id;
  SELECT e.id INTO v_event_id FROM events e WHERE e.id = v_div.event_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_sub.side1_player_id IS NULL OR v_sub.side2_player_id IS NULL THEN
    RAISE EXCEPTION 'submatch_not_ready';
  END IF;

  -- Per-game winner = higher score; sub-match winner = more games.
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_games) LOOP
    v_s1 := (v_elem ->> 'side1_score')::int;
    v_s2 := (v_elem ->> 'side2_score')::int;
    IF v_s1 = v_s2 THEN RAISE EXCEPTION 'invalid_game_score'; END IF;
    IF v_s1 > v_s2 THEN v_g1 := v_g1 + 1; ELSE v_g2 := v_g2 + 1; END IF;
  END LOOP;

  IF v_g1 = v_g2 THEN RAISE EXCEPTION 'no_decisive_winner'; END IF;

  UPDATE tournament_tie_submatches
    SET games = COALESCE(p_games, '[]'::jsonb),
        winner_side = CASE WHEN v_g1 > v_g2 THEN 1 ELSE 2 END,
        status = 'completed'
    WHERE id = p_submatch_id;

  -- Recompute the tie from completed sub-matches.
  SELECT
    COUNT(*) FILTER (WHERE winner_side = 1),
    COUNT(*) FILTER (WHERE winner_side = 2)
  INTO v_side1_wins, v_side2_wins
  FROM tournament_tie_submatches
  WHERE tie_match_id = v_tie.id AND status = 'completed';

  v_win_thr := COALESCE((v_div.tie_config ->> 'win_threshold')::int, 2);

  IF v_side1_wins >= v_win_thr THEN
    v_tie_winner := v_tie.entrant1_id;
  ELSIF v_side2_wins >= v_win_thr THEN
    v_tie_winner := v_tie.entrant2_id;
  ELSE
    -- Not decided yet — mark in progress and stop.
    UPDATE tournament_matches SET status = 'in_progress'
      WHERE id = v_tie.id AND status <> 'completed';
    RETURN;
  END IF;

  UPDATE tournament_matches
    SET winner_entrant_id = v_tie_winner, status = 'completed'
    WHERE id = v_tie.id;

  -- Auto-advance the tie winner into the next tie, then build its sub-matches.
  IF v_tie.next_match_id IS NOT NULL AND v_tie.next_match_slot IS NOT NULL THEN
    IF v_tie.next_match_slot = 1 THEN
      UPDATE tournament_matches SET entrant1_id = v_tie_winner WHERE id = v_tie.next_match_id;
    ELSE
      UPDATE tournament_matches SET entrant2_id = v_tie_winner WHERE id = v_tie.next_match_id;
    END IF;
    UPDATE tournament_matches
      SET status = 'scheduled'
      WHERE id = v_tie.next_match_id AND status = 'pending'
        AND entrant1_id IS NOT NULL AND entrant2_id IS NOT NULL;
    PERFORM _ensure_tie_submatches(v_tie.next_match_id);
  END IF;

  -- Free the court if the tie occupied one.
  IF v_tie.court_id IS NOT NULL THEN
    UPDATE tournament_courts SET status = 'available', current_match_id = NULL
      WHERE id = v_tie.court_id AND current_match_id = v_tie.id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION record_submatch_score(uuid, jsonb) TO authenticated;

-- ─── assign a player to a manual-pairing sub-match slot ─────────────────────
CREATE OR REPLACE FUNCTION set_submatch_player(
  p_submatch_id uuid,
  p_side        int,
  p_player_id   uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT e.id INTO v_event_id
  FROM tournament_tie_submatches s
  JOIN tournament_matches m ON m.id = s.tie_match_id
  JOIN tournament_divisions d ON d.id = m.division_id
  JOIN events e ON e.id = d.event_id
  WHERE s.id = p_submatch_id;
  IF v_event_id IS NULL THEN RAISE EXCEPTION 'submatch_not_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF p_side = 1 THEN
    UPDATE tournament_tie_submatches SET side1_player_id = p_player_id WHERE id = p_submatch_id;
  ELSE
    UPDATE tournament_tie_submatches SET side2_player_id = p_player_id WHERE id = p_submatch_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION set_submatch_player(uuid, int, uuid) TO authenticated;

-- ─── generate_division_bracket — now sets is_tie + builds round-1 sub-matches ──
CREATE OR REPLACE FUNCTION generate_division_bracket(
  p_division_id uuid,
  p_plan        jsonb,
  p_seeds       jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_division  tournament_divisions%ROWTYPE;
  v_elem      jsonb;
  v_idx       int;
  v_next_idx  int;
  v_new_id    uuid;
  v_map       jsonb := '{}'::jsonb;
  v_seed_key  text;
  v_match_id  text;
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_division.event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_division.bracket_generated_at IS NOT NULL THEN
    RAISE EXCEPTION 'bracket_already_generated';
  END IF;

  FOR v_seed_key IN SELECT jsonb_object_keys(p_seeds) LOOP
    UPDATE tournament_entrants
      SET seed = (p_seeds ->> v_seed_key)::int
      WHERE id = v_seed_key::uuid AND division_id = p_division_id;
  END LOOP;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_plan) LOOP
    v_idx := (v_elem ->> 'idx')::int;
    INSERT INTO tournament_matches (
      division_id, bracket_type, round_number, match_number, pool_id,
      entrant1_id, entrant2_id, winner_entrant_id, status, is_tie
    ) VALUES (
      p_division_id,
      v_elem ->> 'bracket_type',
      (v_elem ->> 'round_number')::int,
      (v_elem ->> 'match_number')::int,
      v_elem ->> 'pool_id',
      NULLIF(v_elem ->> 'entrant1_id', '')::uuid,
      NULLIF(v_elem ->> 'entrant2_id', '')::uuid,
      NULLIF(v_elem ->> 'winner_entrant_id', '')::uuid,
      v_elem ->> 'status',
      COALESCE((v_elem ->> 'is_tie')::boolean, false)
    )
    RETURNING id INTO v_new_id;
    v_map := v_map || jsonb_build_object(v_idx::text, v_new_id::text);
  END LOOP;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_plan) LOOP
    IF (v_elem ->> 'next_match_idx') IS NOT NULL THEN
      v_idx      := (v_elem ->> 'idx')::int;
      v_next_idx := (v_elem ->> 'next_match_idx')::int;
      UPDATE tournament_matches
        SET next_match_id   = (v_map ->> (v_next_idx::text))::uuid,
            next_match_slot = (v_elem ->> 'next_match_slot')::int
        WHERE id = (v_map ->> (v_idx::text))::uuid;
    END IF;
  END LOOP;

  -- Build sub-matches for any tie that already has both teams (no-op otherwise).
  FOR v_match_id IN SELECT value FROM jsonb_each_text(v_map) LOOP
    PERFORM _ensure_tie_submatches(v_match_id::uuid);
  END LOOP;

  UPDATE tournament_divisions
    SET bracket_generated_at = now(), status = 'in_progress'
    WHERE id = p_division_id;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_division_bracket(uuid, jsonb, jsonb) TO authenticated;
