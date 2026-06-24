-- ─────────────────────────────────────────────────────────────────────────────
-- seed_division_playoffs (M4) — pools → playoffs
--
-- After all pool matches of a pools_playoff division are completed, the
-- organizer seeds the single-elimination playoff. Dart computes the bracket
-- plan from the pool standings (same shape as generate_division_bracket); this
-- RPC inserts the winners-bracket matches transactionally.
--
-- Guards: organizer only; division must be pools_playoff; all pool matches
-- completed; no winners-bracket matches yet (idempotent).
-- ─────────────────────────────────────────────────────────────────────────────
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

  -- Pass 1: insert playoff matches; build idx → uuid map.
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_plan) LOOP
    v_idx := (v_elem ->> 'idx')::int;
    INSERT INTO tournament_matches (
      division_id, bracket_type, round_number, match_number, pool_id,
      entrant1_id, entrant2_id, winner_entrant_id, status
    ) VALUES (
      p_division_id,
      'winners',
      (v_elem ->> 'round_number')::int,
      (v_elem ->> 'match_number')::int,
      NULL,
      NULLIF(v_elem ->> 'entrant1_id', '')::uuid,
      NULLIF(v_elem ->> 'entrant2_id', '')::uuid,
      NULLIF(v_elem ->> 'winner_entrant_id', '')::uuid,
      v_elem ->> 'status'
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
END;
$$;

GRANT EXECUTE ON FUNCTION seed_division_playoffs(uuid, jsonb) TO authenticated;
