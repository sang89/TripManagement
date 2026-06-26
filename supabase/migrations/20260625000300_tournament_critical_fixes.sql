-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament critical fixes (round-3 audit)
--
--  1. record_submatch_score:
--       a) Guard against scoring into a walked-over parent (raises
--          parent_match_already_decided).
--       b) Auto-promote next court match on tie completion (was clearing
--          current_match_id without promoting the queue).
--
--  2. award_walkover:
--       a) Close all open sub-matches (status = walkover) so that
--          record_submatch_score can no longer overwrite the walkover decision.
--
--  3. start_match: reject is_tie=true matches — their status is driven by
--     sub-match scoring, not a manual Start tap.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. record_submatch_score ─────────────────────────────────────────────────────
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
  v_sub        tournament_tie_submatches%ROWTYPE;
  v_tie        tournament_matches%ROWTYPE;
  v_div        tournament_divisions%ROWTYPE;
  v_event_id   uuid;
  v_elem       jsonb;
  v_s1         int;
  v_s2         int;
  v_g1         int := 0;
  v_g2         int := 0;
  v_win_thr    int;
  v_side1_wins int;
  v_side2_wins int;
  v_tie_winner uuid;
  v_next_q     uuid;
BEGIN
  SELECT * INTO v_sub FROM tournament_tie_submatches WHERE id = p_submatch_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'submatch_not_found'; END IF;

  SELECT * INTO v_tie FROM tournament_matches WHERE id = v_sub.tie_match_id FOR UPDATE;
  SELECT * INTO v_div FROM tournament_divisions WHERE id = v_tie.division_id;
  SELECT e.id INTO v_event_id FROM events e WHERE e.id = v_div.event_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Guard: parent tie match must not already be decided.
  IF v_tie.status IN ('completed', 'walkover', 'bye') THEN
    RAISE EXCEPTION 'parent_match_already_decided';
  END IF;

  IF v_sub.side1_player_id IS NULL OR v_sub.side2_player_id IS NULL THEN
    RAISE EXCEPTION 'submatch_not_ready';
  END IF;

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
    UPDATE tournament_matches SET status = 'in_progress'
      WHERE id = v_tie.id AND status NOT IN ('completed', 'walkover', 'bye');
    RETURN;
  END IF;

  UPDATE tournament_matches
    SET winner_entrant_id = v_tie_winner,
        status            = 'completed',
        ended_at          = COALESCE(ended_at, now())
    WHERE id = v_tie.id;

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

  -- Free the court and promote next queued match.
  IF v_tie.court_id IS NOT NULL THEN
    SELECT id INTO v_next_q
    FROM tournament_matches
    WHERE court_id = v_tie.court_id
      AND id <> v_tie.id
      AND status NOT IN ('completed', 'walkover', 'bye')
    ORDER BY scheduled_order NULLS LAST
    LIMIT 1;

    UPDATE tournament_courts
      SET current_match_id = v_next_q,
          status = CASE WHEN v_next_q IS NULL THEN 'available' ELSE 'in_use' END
      WHERE id = v_tie.court_id AND current_match_id = v_tie.id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION record_submatch_score(uuid, jsonb) TO authenticated;

-- 2. award_walkover — close sub-matches before marking parent decided ──────────
CREATE OR REPLACE FUNCTION award_walkover(
  p_match_id          uuid,
  p_winner_entrant_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match  tournament_matches%ROWTYPE;
  v_event_id uuid;
  v_next_q   uuid;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM tournament_divisions d JOIN events e ON e.id = d.event_id
  WHERE d.id = v_match.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_match.status IN ('completed', 'walkover', 'bye') THEN
    RAISE EXCEPTION 'match_already_decided';
  END IF;

  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  IF p_winner_entrant_id NOT IN (v_match.entrant1_id, v_match.entrant2_id) THEN
    RAISE EXCEPTION 'winner_not_in_match';
  END IF;

  -- For tie matches: close all open sub-matches first so record_submatch_score
  -- cannot overwrite this walkover decision after it's recorded.
  IF v_match.is_tie THEN
    UPDATE tournament_tie_submatches
      SET status = 'walkover'
      WHERE tie_match_id = p_match_id
        AND status NOT IN ('completed', 'walkover');
  END IF;

  UPDATE tournament_matches
    SET winner_entrant_id = p_winner_entrant_id,
        status            = 'walkover',
        started_at        = COALESCE(started_at, now()),
        ended_at          = COALESCE(ended_at, now())
    WHERE id = p_match_id;

  IF v_match.next_match_id IS NOT NULL AND v_match.next_match_slot IS NOT NULL THEN
    IF v_match.next_match_slot = 1 THEN
      UPDATE tournament_matches SET entrant1_id = p_winner_entrant_id WHERE id = v_match.next_match_id;
    ELSE
      UPDATE tournament_matches SET entrant2_id = p_winner_entrant_id WHERE id = v_match.next_match_id;
    END IF;
    UPDATE tournament_matches
      SET status = 'scheduled'
      WHERE id = v_match.next_match_id
        AND status = 'pending'
        AND entrant1_id IS NOT NULL
        AND entrant2_id IS NOT NULL;
  END IF;

  IF v_match.court_id IS NOT NULL THEN
    SELECT id INTO v_next_q
    FROM tournament_matches
    WHERE court_id = v_match.court_id
      AND id <> p_match_id
      AND status NOT IN ('completed', 'walkover', 'bye')
    ORDER BY scheduled_order NULLS LAST
    LIMIT 1;

    UPDATE tournament_courts
      SET current_match_id = v_next_q,
          status = CASE WHEN v_next_q IS NULL THEN 'available' ELSE 'in_use' END
      WHERE id = v_match.court_id AND current_match_id = p_match_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION award_walkover(uuid, uuid) TO authenticated;

-- 3. start_match — reject tie matches ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION start_match(p_match_id uuid)
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

  IF v_match.status IN ('completed', 'walkover', 'bye') THEN
    RAISE EXCEPTION 'match_already_decided';
  END IF;

  IF v_match.is_tie THEN
    RAISE EXCEPTION 'tie_matches_start_via_submatches';
  END IF;

  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  IF v_match.started_at IS NOT NULL THEN
    RAISE EXCEPTION 'match_already_started';
  END IF;

  UPDATE tournament_matches
    SET started_at = now(), status = 'in_progress'
    WHERE id = p_match_id;

  IF v_match.court_id IS NOT NULL THEN
    UPDATE tournament_courts
      SET current_match_id = p_match_id, status = 'in_use'
      WHERE id = v_match.court_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION start_match(uuid) TO authenticated;

-- 4. assign_match_to_court — add walkover to undoable statuses ───────────────
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
  v_match       tournament_matches%ROWTYPE;
  v_event_id    uuid;
  v_court_event uuid;
  v_next_ord    int;
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

  SELECT event_id INTO v_court_event FROM tournament_courts WHERE id = p_court_id;
  IF v_court_event IS DISTINCT FROM v_event_id THEN
    RAISE EXCEPTION 'court_event_mismatch';
  END IF;

  IF v_match.status IN ('completed', 'walkover', 'bye') THEN
    RAISE EXCEPTION 'match_not_assignable';
  END IF;

  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  SELECT COALESCE(MAX(scheduled_order), 0) + 1 INTO v_next_ord
  FROM tournament_matches
  WHERE court_id = p_court_id AND status NOT IN ('completed', 'walkover', 'bye');

  UPDATE tournament_matches
    SET court_id = p_court_id, scheduled_order = v_next_ord
    WHERE id = p_match_id;

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

-- 5. seed_division_playoffs — include walkover/bye in pool-complete guard ──────
CREATE OR REPLACE FUNCTION seed_division_playoffs(
  p_division_id uuid,
  p_plan        jsonb
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
  v_pending   int;
  v_match_id  text;
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_division.event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_division.format <> 'pools_playoff' THEN
    RAISE EXCEPTION 'not_a_pools_division';
  END IF;

  SELECT count(*) INTO v_pending
  FROM tournament_matches
  WHERE division_id = p_division_id AND bracket_type = 'pool'
    AND status NOT IN ('completed', 'walkover', 'bye');
  IF v_pending > 0 THEN
    RAISE EXCEPTION 'pools_not_complete';
  END IF;

  IF EXISTS (
    SELECT 1 FROM tournament_matches
    WHERE division_id = p_division_id AND bracket_type = 'winners'
  ) THEN
    RAISE EXCEPTION 'playoffs_already_seeded';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_plan) LOOP
    v_idx := (v_elem ->> 'idx')::int;
    INSERT INTO tournament_matches (
      division_id, bracket_type, round_number, match_number, pool_id,
      entrant1_id, entrant2_id, winner_entrant_id, status, is_tie
    ) VALUES (
      p_division_id,
      'winners',
      (v_elem ->> 'round_number')::int,
      (v_elem ->> 'match_number')::int,
      NULL,
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

  FOR v_match_id IN
    SELECT id::text FROM tournament_matches
    WHERE division_id = p_division_id AND bracket_type = 'winners' AND is_tie
      AND entrant1_id IS NOT NULL AND entrant2_id IS NOT NULL
  LOOP
    PERFORM _ensure_tie_submatches(v_match_id::uuid);
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION seed_division_playoffs(uuid, jsonb) TO authenticated;
