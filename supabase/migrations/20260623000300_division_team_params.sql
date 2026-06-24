-- Extend create_tournament_division with team-kind params (entrant_kind,
-- roster_size, tie_config). Signature changes, so drop the old overload first.
DROP FUNCTION IF EXISTS create_tournament_division(uuid, text, text, text, text, text, jsonb, integer, integer, integer);

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
  p_advance_per_pool integer DEFAULT NULL,
  p_entrant_kind     text    DEFAULT 'individual',
  p_roster_size      integer DEFAULT NULL,
  p_tie_config       jsonb   DEFAULT NULL
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
    entrant_kind, roster_size, tie_config, status
  ) VALUES (
    p_event_id, p_name, p_sport, p_discipline, p_skill_level, p_format,
    COALESCE(p_scoring_config, '{}'::jsonb), v_team_size,
    p_entrant_cap, p_pool_count, p_advance_per_pool,
    COALESCE(p_entrant_kind, 'individual'), p_roster_size, p_tie_config,
    'registration'
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION create_tournament_division(uuid, text, text, text, text, text, jsonb, integer, integer, integer, text, integer, jsonb) TO authenticated;
