-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament customization M7 — team ties + sub-matches
--
-- A "tie" is a tournament_matches row (team entrant1 vs team entrant2) with
-- is_tie = true. Its sub-matches (player-vs-player by roster position) live in
-- tournament_tie_submatches. The tie winner is derived from sub-match results;
-- it reuses the existing next_match auto-advance plumbing.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE tournament_matches
  ADD COLUMN IF NOT EXISTS is_tie boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS tournament_tie_submatches (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tie_match_id    uuid        NOT NULL REFERENCES tournament_matches(id) ON DELETE CASCADE,
  position        integer     NOT NULL,
  side1_player_id uuid        REFERENCES tournament_entrant_players(id) ON DELETE SET NULL,
  side2_player_id uuid        REFERENCES tournament_entrant_players(id) ON DELETE SET NULL,
  games           jsonb       NOT NULL DEFAULT '[]'::jsonb,
  winner_side     integer     CHECK (winner_side IS NULL OR winner_side IN (1, 2)),
  status          text        NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('pending', 'scheduled', 'in_progress', 'completed')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tie_match_id, position)
);

ALTER TABLE tournament_tie_submatches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_tie_submatches
  USING (
    EXISTS (
      SELECT 1 FROM tournament_matches m
      JOIN tournament_divisions d ON d.id = m.division_id
      JOIN events e ON e.id = d.event_id
      WHERE m.id = tournament_tie_submatches.tie_match_id AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "members can read submatches" ON tournament_tie_submatches
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournament_matches m
      JOIN tournament_divisions d ON d.id = m.division_id
      WHERE m.id = tournament_tie_submatches.tie_match_id
        AND auth_user_is_event_member(d.event_id)
    )
  );

CREATE INDEX IF NOT EXISTS idx_tie_submatches_tie ON tournament_tie_submatches(tie_match_id);

ALTER TABLE tournament_tie_submatches REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_tie_submatches;

-- ─── _ensure_tie_submatches — create a tie's sub-matches once both teams known ──
-- same_rank: pair roster position i of each team (up to submatch_count).
-- manual: create empty positioned rows for the organizer to assign players.
CREATE OR REPLACE FUNCTION _ensure_tie_submatches(p_tie_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match   tournament_matches%ROWTYPE;
  v_div     tournament_divisions%ROWTYPE;
  v_n       integer;
  v_pairing text;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_tie_match_id;
  IF NOT FOUND OR NOT v_match.is_tie THEN RETURN; END IF;
  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM tournament_tie_submatches WHERE tie_match_id = p_tie_match_id) THEN
    RETURN;
  END IF;

  SELECT * INTO v_div FROM tournament_divisions WHERE id = v_match.division_id;
  v_n := COALESCE((v_div.tie_config ->> 'submatch_count')::int, 3);
  v_pairing := COALESCE(v_div.tie_config ->> 'pairing_rule', 'same_rank');

  IF v_pairing = 'same_rank' THEN
    INSERT INTO tournament_tie_submatches (tie_match_id, position, side1_player_id, side2_player_id)
    SELECT p_tie_match_id, a.rn, a.id, b.id
    FROM (
      SELECT id, row_number() OVER (ORDER BY sort_order, player_rank) AS rn
      FROM tournament_entrant_players WHERE entrant_id = v_match.entrant1_id
    ) a
    JOIN (
      SELECT id, row_number() OVER (ORDER BY sort_order, player_rank) AS rn
      FROM tournament_entrant_players WHERE entrant_id = v_match.entrant2_id
    ) b ON a.rn = b.rn
    WHERE a.rn <= v_n;
  ELSE
    INSERT INTO tournament_tie_submatches (tie_match_id, position)
    SELECT p_tie_match_id, g FROM generate_series(1, v_n) AS g;
  END IF;
END;
$$;
