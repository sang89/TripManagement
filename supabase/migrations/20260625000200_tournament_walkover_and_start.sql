-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament walkover + start_match RPC + court auto-promotion fix
--
--  1. award_walkover — declare a no-show/forfeit winner without entering scores.
--     Same court-free + next-match-advancement logic as record_match_score.
--  2. start_match — replaces the Dart direct UPDATE so that starting a match
--     also syncs tournament_courts.status = 'in_use' and current_match_id.
--  3. record_match_score fix — auto-promote the next queued match on the court
--     after the current match completes (was clearing current_match_id to NULL
--     without looking at the rest of the queue).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. award_walkover ────────────────────────────────────────────────────────────
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
  v_match    tournament_matches%ROWTYPE;
  v_event_id uuid;
  v_next     tournament_matches%ROWTYPE;
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

  UPDATE tournament_matches
    SET winner_entrant_id = p_winner_entrant_id,
        status            = 'walkover',
        started_at        = COALESCE(started_at, now()),
        ended_at          = COALESCE(ended_at, now())
    WHERE id = p_match_id;

  -- Auto-advance winner to next match.
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

  -- Free the court and promote the next queued match.
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

-- 2. start_match ──────────────────────────────────────────────────────────────
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

  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  IF v_match.started_at IS NOT NULL THEN
    RAISE EXCEPTION 'match_already_started';
  END IF;

  UPDATE tournament_matches
    SET started_at = now(), status = 'in_progress'
    WHERE id = p_match_id;

  -- Ensure the court reflects this match as current and in-use.
  IF v_match.court_id IS NOT NULL THEN
    UPDATE tournament_courts
      SET current_match_id = p_match_id, status = 'in_use'
      WHERE id = v_match.court_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION start_match(uuid) TO authenticated;

-- 3. record_match_score — auto-promote next court match ───────────────────────
CREATE OR REPLACE FUNCTION record_match_score(
  p_match_id uuid,
  p_games    jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match     tournament_matches%ROWTYPE;
  v_event_id  uuid;
  v_elem      jsonb;
  v_s1        int;
  v_s2        int;
  v_g1        int := 0;
  v_g2        int := 0;
  v_winner    uuid;
  v_next      tournament_matches%ROWTYPE;
  v_next_q    uuid;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM tournament_divisions d JOIN events e ON e.id = d.event_id
  WHERE d.id = v_match.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_match.status = 'bye' THEN
    RAISE EXCEPTION 'cannot_score_bye';
  END IF;

  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  IF v_match.next_match_id IS NOT NULL THEN
    SELECT * INTO v_next FROM tournament_matches WHERE id = v_match.next_match_id;
    IF FOUND AND v_next.status = 'completed' THEN
      RAISE EXCEPTION 'downstream_match_played';
    END IF;
  END IF;

  DELETE FROM tournament_match_games WHERE match_id = p_match_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_games) LOOP
    v_s1 := (v_elem ->> 'entrant1_score')::int;
    v_s2 := (v_elem ->> 'entrant2_score')::int;
    IF v_s1 = v_s2 THEN
      RAISE EXCEPTION 'invalid_game_score';
    END IF;

    IF v_s1 > v_s2 THEN v_g1 := v_g1 + 1;
    ELSE v_g2 := v_g2 + 1;
    END IF;

    INSERT INTO tournament_match_games (
      match_id, game_number, entrant1_score, entrant2_score, winner_entrant_id
    ) VALUES (
      p_match_id,
      (v_elem ->> 'game_number')::int,
      v_s1, v_s2,
      CASE WHEN v_s1 > v_s2 THEN v_match.entrant1_id ELSE v_match.entrant2_id END
    );
  END LOOP;

  IF v_g1 = v_g2 THEN RAISE EXCEPTION 'no_decisive_winner'; END IF;

  v_winner := CASE WHEN v_g1 > v_g2 THEN v_match.entrant1_id ELSE v_match.entrant2_id END;

  UPDATE tournament_matches
    SET winner_entrant_id = v_winner,
        status            = 'completed',
        started_at        = COALESCE(started_at, now()),
        ended_at          = COALESCE(ended_at, now())
    WHERE id = p_match_id;

  IF v_match.next_match_id IS NOT NULL AND v_match.next_match_slot IS NOT NULL THEN
    IF v_match.next_match_slot = 1 THEN
      UPDATE tournament_matches SET entrant1_id = v_winner WHERE id = v_match.next_match_id;
    ELSE
      UPDATE tournament_matches SET entrant2_id = v_winner WHERE id = v_match.next_match_id;
    END IF;
    UPDATE tournament_matches
      SET status = 'scheduled'
      WHERE id = v_match.next_match_id
        AND status = 'pending'
        AND entrant1_id IS NOT NULL
        AND entrant2_id IS NOT NULL;
  END IF;

  -- Free the court and promote the next queued match.
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

GRANT EXECUTE ON FUNCTION record_match_score(uuid, jsonb) TO authenticated;
