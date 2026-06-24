-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament event type — RPCs (M2: divisions, entrants, courts)
--
-- Bracket generation (generate_division_bracket) and score recording
-- (record_match_score) are added in later migrations (M3/M4).
--
-- All RPCs are SECURITY DEFINER with a fixed search_path and explicit auth
-- checks, mirroring the signup session RPCs.
-- ─────────────────────────────────────────────────────────────────────────────

-- Column list returned by division RPCs (kept in sync with the Dart model).
-- create_tournament_division / update_tournament_division both return this shape.

-- ─── 1. create_tournament_division ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION create_tournament_division(
  p_event_id         uuid,
  p_name             text,
  p_sport            text,
  p_discipline       text,
  p_skill_level      text,
  p_format           text,
  p_scoring_config   jsonb,
  p_entrant_cap      integer DEFAULT NULL,
  p_pool_count       integer DEFAULT NULL,
  p_advance_per_pool integer DEFAULT NULL
)
RETURNS SETOF tournament_divisions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_team_size integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND event_type = 'tournament') THEN
    RAISE EXCEPTION 'not_a_tournament_event';
  END IF;

  v_team_size := CASE WHEN p_discipline = 'singles' THEN 1 ELSE 2 END;

  RETURN QUERY
  INSERT INTO tournament_divisions (
    event_id, name, sport, discipline, skill_level, format,
    scoring_config, team_size, entrant_cap, pool_count, advance_per_pool,
    status
  ) VALUES (
    p_event_id, p_name, p_sport, p_discipline, p_skill_level, p_format,
    COALESCE(p_scoring_config, '{}'::jsonb), v_team_size,
    p_entrant_cap, p_pool_count, p_advance_per_pool,
    'registration'
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION create_tournament_division(uuid, text, text, text, text, text, jsonb, integer, integer, integer) TO authenticated;

-- ─── 2. update_tournament_division — edit config before the bracket is built ──
CREATE OR REPLACE FUNCTION update_tournament_division(
  p_division_id      uuid,
  p_name             text    DEFAULT NULL,
  p_scoring_config   jsonb   DEFAULT NULL,
  p_entrant_cap      integer DEFAULT NULL,
  p_clear_entrant_cap boolean DEFAULT false,
  p_pool_count       integer DEFAULT NULL,
  p_advance_per_pool integer DEFAULT NULL
)
RETURNS SETOF tournament_divisions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM tournament_divisions d JOIN events e ON e.id = d.event_id
    WHERE d.id = p_division_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
  UPDATE tournament_divisions SET
    name             = COALESCE(p_name, name),
    scoring_config   = COALESCE(p_scoring_config, scoring_config),
    entrant_cap      = CASE WHEN p_clear_entrant_cap THEN NULL ELSE COALESCE(p_entrant_cap, entrant_cap) END,
    pool_count       = COALESCE(p_pool_count, pool_count),
    advance_per_pool = COALESCE(p_advance_per_pool, advance_per_pool)
  WHERE id = p_division_id
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION update_tournament_division(uuid, text, jsonb, integer, boolean, integer, integer) TO authenticated;

-- ─── 3. delete_tournament_division ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION delete_tournament_division(p_division_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM tournament_divisions d JOIN events e ON e.id = d.event_id
    WHERE d.id = p_division_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM tournament_divisions WHERE id = p_division_id;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_tournament_division(uuid) TO authenticated;

-- ─── 4. register_tournament_entrant ─────────────────────────────────────────
-- Any event member (organizer or guest) may register a team while the
-- division's registration is open and the cap is not reached.
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
  v_division   tournament_divisions%ROWTYPE;
  v_going      integer;
BEGIN
  SELECT * INTO v_division FROM tournament_divisions WHERE id = p_division_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'division_not_found'; END IF;

  IF NOT auth_user_is_event_member(v_division.event_id) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_division.bracket_generated_at IS NOT NULL OR v_division.status = 'completed' THEN
    RAISE EXCEPTION 'registration_closed';
  END IF;

  -- Doubles/mixed require a second player; singles must not have one.
  IF v_division.team_size = 2 AND (p_player2_name IS NULL OR TRIM(p_player2_name) = '') THEN
    RAISE EXCEPTION 'second_player_required';
  END IF;
  IF v_division.team_size = 1 AND p_player2_name IS NOT NULL AND TRIM(p_player2_name) <> '' THEN
    RAISE EXCEPTION 'singles_no_partner';
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

-- ─── 5. withdraw_tournament_entrant — soft (organizer or a linked player) ────
CREATE OR REPLACE FUNCTION withdraw_tournament_entrant(p_entrant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entrant tournament_entrants%ROWTYPE;
  v_event_id uuid;
BEGIN
  SELECT * INTO v_entrant FROM tournament_entrants WHERE id = p_entrant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'entrant_not_found'; END IF;

  SELECT d.event_id INTO v_event_id FROM tournament_divisions d WHERE d.id = v_entrant.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid())
     AND v_entrant.player1_user_id IS DISTINCT FROM auth.uid()
     AND v_entrant.player2_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  UPDATE tournament_entrants SET status = 'withdrawn' WHERE id = p_entrant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION withdraw_tournament_entrant(uuid) TO authenticated;

-- ─── 6. remove_tournament_entrant — organizer hard delete ───────────────────
CREATE OR REPLACE FUNCTION remove_tournament_entrant(p_entrant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT d.event_id INTO v_event_id
  FROM tournament_entrants en JOIN tournament_divisions d ON d.id = en.division_id
  WHERE en.id = p_entrant_id;
  IF v_event_id IS NULL THEN RAISE EXCEPTION 'entrant_not_found'; END IF;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM tournament_entrants WHERE id = p_entrant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION remove_tournament_entrant(uuid) TO authenticated;

-- ─── 7. add_tournament_court ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION add_tournament_court(p_event_id uuid, p_name text)
RETURNS SETOF tournament_courts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_order integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_next_order
  FROM tournament_courts WHERE event_id = p_event_id;

  RETURN QUERY
  INSERT INTO tournament_courts (event_id, name, sort_order)
  VALUES (p_event_id, p_name, v_next_order)
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION add_tournament_court(uuid, text) TO authenticated;

-- ─── 8. update_tournament_court — rename / change status ─────────────────────
CREATE OR REPLACE FUNCTION update_tournament_court(
  p_court_id uuid,
  p_name     text DEFAULT NULL,
  p_status   text DEFAULT NULL
)
RETURNS SETOF tournament_courts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM tournament_courts c JOIN events e ON e.id = c.event_id
    WHERE c.id = p_court_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
  UPDATE tournament_courts SET
    name   = COALESCE(p_name, name),
    status = COALESCE(p_status, status)
  WHERE id = p_court_id
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION update_tournament_court(uuid, text, text) TO authenticated;

-- ─── 9. delete_tournament_court ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION delete_tournament_court(p_court_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM tournament_courts c JOIN events e ON e.id = c.event_id
    WHERE c.id = p_court_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM tournament_courts WHERE id = p_court_id;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_tournament_court(uuid) TO authenticated;
