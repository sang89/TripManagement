-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament RPC correctness fixes (post-audit)
--
--  1. tournament_matches: CHECK constraint started_at <= ended_at.
--  2. tournament_divisions: index on bundle_id.
--  3. assign_match_to_court: reject matches where either entrant slot is empty.
--  4. seed_division_playoffs: include is_tie in INSERT + build sub-matches for
--     ties that already have both teams (mirrors generate_division_bracket).
--  5. record_match_score: auto-stamp started_at = COALESCE(started_at, now())
--     when a match is scored without having been explicitly started.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Time-ordering constraint ─────────────────────────────────────────────────
ALTER TABLE tournament_matches
  ADD CONSTRAINT chk_match_time_order
    CHECK (started_at IS NULL OR ended_at IS NULL OR started_at <= ended_at);

-- 2. bundle_id index ──────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tournament_divisions_bundle
  ON tournament_divisions(bundle_id) WHERE bundle_id IS NOT NULL;

-- 3. assign_match_to_court — reject not-ready matches ─────────────────────────
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

  IF v_match.status IN ('completed', 'bye') THEN
    RAISE EXCEPTION 'match_not_assignable';
  END IF;

  -- Both entrant slots must be filled before queuing on a court.
  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  SELECT COALESCE(MAX(scheduled_order), 0) + 1 INTO v_next_ord
  FROM tournament_matches
  WHERE court_id = p_court_id AND status <> 'completed';

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

-- 4. seed_division_playoffs — include is_tie + build sub-matches for ties ─────
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

  -- All pool matches must be done.
  SELECT count(*) INTO v_pending
  FROM tournament_matches
  WHERE division_id = p_division_id AND bracket_type = 'pool' AND status <> 'completed';
  IF v_pending > 0 THEN
    RAISE EXCEPTION 'pools_not_complete';
  END IF;

  -- Don't double-seed.
  IF EXISTS (
    SELECT 1 FROM tournament_matches
    WHERE division_id = p_division_id AND bracket_type = 'winners'
  ) THEN
    RAISE EXCEPTION 'playoffs_already_seeded';
  END IF;

  -- Pass 1: insert playoff matches, including is_tie from the plan.
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

  -- Pass 2: wire next_match.
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

  -- Pass 3: build sub-matches for tie matches that already have both teams.
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

-- 5. record_match_score — auto-stamp started_at if not already set ─────────────
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

    IF v_s1 > v_s2 THEN
      v_g1 := v_g1 + 1;
    ELSE
      v_g2 := v_g2 + 1;
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

  IF v_g1 = v_g2 THEN
    RAISE EXCEPTION 'no_decisive_winner';
  END IF;

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

  IF v_match.court_id IS NOT NULL THEN
    UPDATE tournament_courts
      SET status = 'available', current_match_id = NULL
      WHERE id = v_match.court_id AND current_match_id = p_match_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION record_match_score(uuid, jsonb) TO authenticated;
