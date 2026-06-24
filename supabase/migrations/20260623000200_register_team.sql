-- ─────────────────────────────────────────────────────────────────────────────
-- register_tournament_team (M6) — register a team entrant with a ranked roster.
--
--   p_players — array of { name, rank?, user_id? } (rank defaults to position)
--
-- Any event member may register while the division's registration is open and
-- the cap is not reached. Mirrors register_tournament_entrant's guards.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION register_tournament_team(
  p_division_id uuid,
  p_team_name   text,
  p_players     jsonb
)
RETURNS SETOF tournament_entrants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_division   tournament_divisions%ROWTYPE;
  v_count      integer;
  v_entrant_id uuid;
  v_elem       jsonb;
  v_idx        integer := 0;
  v_first_name text;
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;

  IF NOT auth_user_is_event_member(v_division.event_id) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_division.bracket_generated_at IS NOT NULL OR v_division.status = 'completed' THEN
    RAISE EXCEPTION 'registration_closed';
  END IF;

  IF jsonb_array_length(COALESCE(p_players, '[]'::jsonb)) < 1 THEN
    RAISE EXCEPTION 'roster_required';
  END IF;

  IF v_division.entrant_cap IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count
    FROM tournament_entrants
    WHERE division_id = p_division_id AND status <> 'withdrawn';
    IF v_count >= v_division.entrant_cap THEN
      RAISE EXCEPTION 'division_full';
    END IF;
  END IF;

  v_first_name := COALESCE(p_players -> 0 ->> 'name', p_team_name);

  INSERT INTO tournament_entrants (division_id, team_name, player1_name)
  VALUES (p_division_id, p_team_name, v_first_name)
  RETURNING id INTO v_entrant_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_players) LOOP
    INSERT INTO tournament_entrant_players (
      entrant_id, name, player_rank, sort_order, user_id
    ) VALUES (
      v_entrant_id,
      COALESCE(NULLIF(v_elem ->> 'name', ''), 'Player ' || (v_idx + 1)),
      COALESCE((v_elem ->> 'rank')::int, v_idx + 1),
      v_idx,
      NULLIF(v_elem ->> 'user_id', '')::uuid
    );
    v_idx := v_idx + 1;
  END LOOP;

  RETURN QUERY SELECT * FROM tournament_entrants WHERE id = v_entrant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION register_tournament_team(uuid, text, jsonb) TO authenticated;
