-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament customization M6 — team rosters
--
-- Divisions can now be "team" kind: entrants are teams with a ranked roster of N
-- players (e.g. 6 teams × 10 players ranked 1–10), in addition to the existing
-- "individual" (1–2 player) entrants. Roster rows live in a child table.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE tournament_divisions
  ADD COLUMN IF NOT EXISTS entrant_kind text NOT NULL DEFAULT 'individual'
    CHECK (entrant_kind IN ('individual', 'team'));
ALTER TABLE tournament_divisions
  ADD COLUMN IF NOT EXISTS roster_size integer
    CHECK (roster_size IS NULL OR roster_size > 0);

-- ─── tournament_entrant_players (roster) ────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_entrant_players (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  entrant_id  uuid        NOT NULL REFERENCES tournament_entrants(id) ON DELETE CASCADE,
  user_id     uuid        REFERENCES auth.users(id),
  name        text        NOT NULL,
  player_rank integer,
  sort_order  integer     NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tournament_entrant_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_entrant_players
  USING (
    EXISTS (
      SELECT 1 FROM tournament_entrants en
      JOIN tournament_divisions d ON d.id = en.division_id
      JOIN events e ON e.id = d.event_id
      WHERE en.id = tournament_entrant_players.entrant_id
        AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "members can read roster" ON tournament_entrant_players
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournament_entrants en
      JOIN tournament_divisions d ON d.id = en.division_id
      WHERE en.id = tournament_entrant_players.entrant_id
        AND auth_user_is_event_member(d.event_id)
    )
  );

CREATE INDEX IF NOT EXISTS idx_entrant_players_entrant
  ON tournament_entrant_players(entrant_id);

-- Realtime.
ALTER TABLE tournament_entrant_players REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_entrant_players;
