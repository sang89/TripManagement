-- ─────────────────────────────────────────────────────────────────────────────
-- generate_division_bracket (M3)
--
-- Dart computes the full bracket plan (seeding, pairings, byes pre-advanced,
-- next-match wiring as local indices) and passes it as JSONB. This RPC just
-- inserts it transactionally:
--   p_plan  — array of match specs (idx, round/match number, entrant slots,
--             status, bye winner, next_match_idx/slot)
--   p_seeds — { entrantId: seedNumber }
--
-- Two-pass insert: insert all matches (capturing a local idx → uuid map), then
-- wire next_match_id/slot from the map. Idempotent guard: refuses if a bracket
-- already exists for the division.
-- ─────────────────────────────────────────────────────────────────────────────
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
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_division.event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_division.bracket_generated_at IS NOT NULL THEN
    RAISE EXCEPTION 'bracket_already_generated';
  END IF;

  -- Persist the assigned seeds.
  FOR v_seed_key IN SELECT jsonb_object_keys(p_seeds) LOOP
    UPDATE tournament_entrants
      SET seed = (p_seeds ->> v_seed_key)::int
      WHERE id = v_seed_key::uuid AND division_id = p_division_id;
  END LOOP;

  -- Pass 1: insert matches (no next-match wiring yet), build idx → uuid map.
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_plan) LOOP
    v_idx := (v_elem ->> 'idx')::int;
    INSERT INTO tournament_matches (
      division_id, bracket_type, round_number, match_number, pool_id,
      entrant1_id, entrant2_id, winner_entrant_id, status
    ) VALUES (
      p_division_id,
      v_elem ->> 'bracket_type',
      (v_elem ->> 'round_number')::int,
      (v_elem ->> 'match_number')::int,
      v_elem ->> 'pool_id',
      NULLIF(v_elem ->> 'entrant1_id', '')::uuid,
      NULLIF(v_elem ->> 'entrant2_id', '')::uuid,
      NULLIF(v_elem ->> 'winner_entrant_id', '')::uuid,
      v_elem ->> 'status'
    )
    RETURNING id INTO v_new_id;
    v_map := v_map || jsonb_build_object(v_idx::text, v_new_id::text);
  END LOOP;

  -- Pass 2: wire next_match_id / next_match_slot from the local index map.
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

  UPDATE tournament_divisions
    SET bracket_generated_at = now(), status = 'in_progress'
    WHERE id = p_division_id;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_division_bracket(uuid, jsonb, jsonb) TO authenticated;
