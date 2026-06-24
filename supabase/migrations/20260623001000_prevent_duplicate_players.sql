-- ─────────────────────────────────────────────────────────────────────────────
-- Prevent a player from being entered twice in the same division.
--
-- Standard racquet-tournament rule: one entry per player per draw. A player may
-- play in OTHER divisions (different division_id), and obviously cannot partner
-- themselves. Matching is by linked account (user_id) when present AND by
-- case-insensitive name (covers non-app/guest players entered by name).
-- ─────────────────────────────────────────────────────────────────────────────

-- register_tournament_entrant (individual divisions) + dedup checks.
CREATE OR REPLACE FUNCTION register_tournament_entrant(
  p_division_id     uuid,
  p_team_name       text,
  p_player1_name    text,
  p_player1_user_id uuid DEFAULT NULL,
  p_player2_name    text DEFAULT NULL,
  p_player2_user_id uuid DEFAULT NULL
)
RETURNS SETOF tournament_entrants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_division tournament_divisions%ROWTYPE;
  v_going    integer;
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;

  IF NOT auth_user_is_event_member(v_division.event_id) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_division.bracket_generated_at IS NOT NULL OR v_division.status = 'completed' THEN
    RAISE EXCEPTION 'registration_closed';
  END IF;

  IF v_division.team_size = 2 AND (p_player2_name IS NULL OR TRIM(p_player2_name) = '') THEN
    RAISE EXCEPTION 'second_player_required';
  END IF;
  IF v_division.team_size = 1 AND p_player2_name IS NOT NULL AND TRIM(p_player2_name) <> '' THEN
    RAISE EXCEPTION 'singles_no_partner';
  END IF;

  -- A player cannot partner themselves.
  IF v_division.team_size = 2 AND (
       lower(trim(p_player1_name)) = lower(trim(COALESCE(p_player2_name, '')))
       OR (p_player1_user_id IS NOT NULL AND p_player1_user_id = p_player2_user_id)
     ) THEN
    RAISE EXCEPTION 'duplicate_player_in_team';
  END IF;

  -- Neither new player may already be in an active entrant of this division.
  IF EXISTS (
    SELECT 1
    FROM tournament_entrants e
    CROSS JOIN LATERAL (VALUES
      (e.player1_name, e.player1_user_id),
      (e.player2_name, e.player2_user_id)) AS ex(nm, uid)
    CROSS JOIN LATERAL (VALUES
      (p_player1_name, p_player1_user_id),
      (CASE WHEN v_division.team_size = 2 THEN p_player2_name END,
       CASE WHEN v_division.team_size = 2 THEN p_player2_user_id END)) AS nw(nm, uid)
    WHERE e.division_id = p_division_id AND e.status <> 'withdrawn'
      AND (
        (ex.nm IS NOT NULL AND nw.nm IS NOT NULL
           AND trim(nw.nm) <> '' AND lower(trim(ex.nm)) = lower(trim(nw.nm)))
        OR (ex.uid IS NOT NULL AND nw.uid IS NOT NULL AND ex.uid = nw.uid)
      )
  ) THEN
    RAISE EXCEPTION 'player_already_registered';
  END IF;

  IF v_division.entrant_cap IS NOT NULL THEN
    SELECT COUNT(*) INTO v_going
    FROM tournament_entrants
    WHERE division_id = p_division_id AND status <> 'withdrawn';
    IF v_going >= v_division.entrant_cap THEN
      RAISE EXCEPTION 'division_full';
    END IF;
  END IF;

  RETURN QUERY
  INSERT INTO tournament_entrants (
    division_id, team_name, player1_name, player1_user_id,
    player2_name, player2_user_id
  ) VALUES (
    p_division_id, p_team_name, p_player1_name, p_player1_user_id,
    CASE WHEN v_division.team_size = 2 THEN p_player2_name ELSE NULL END,
    CASE WHEN v_division.team_size = 2 THEN p_player2_user_id ELSE NULL END
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION register_tournament_entrant(uuid, text, text, uuid, text, uuid) TO authenticated;

-- register_tournament_team (team divisions) + dedup checks.
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

  -- No duplicate player within this roster (by name).
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_players) np
    WHERE trim(np ->> 'name') <> ''
    GROUP BY lower(trim(np ->> 'name'))
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'duplicate_player_in_team';
  END IF;

  -- No roster player already on another active team in this division.
  IF EXISTS (
    SELECT 1
    FROM tournament_entrant_players ep
    JOIN tournament_entrants en ON en.id = ep.entrant_id
    CROSS JOIN LATERAL jsonb_array_elements(p_players) AS np
    WHERE en.division_id = p_division_id AND en.status <> 'withdrawn'
      AND (
        (trim(np ->> 'name') <> '' AND lower(trim(ep.name)) = lower(trim(np ->> 'name')))
        OR (ep.user_id IS NOT NULL AND (np ->> 'user_id') IS NOT NULL
            AND ep.user_id = (np ->> 'user_id')::uuid)
      )
  ) THEN
    RAISE EXCEPTION 'player_already_registered';
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
