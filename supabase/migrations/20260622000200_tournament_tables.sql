-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament event type — schema (M2)
--
-- A tournament Event owns:
--   • tournament_divisions    — one row per draw (discipline + skill level +
--                               format + scoring config)
--   • tournament_entrants     — a team (1 or 2 players) registered into a division
--   • tournament_matches      — bracket/pool matches (self-FK next_match_id for
--                               winner auto-advance); populated at bracket
--                               generation (M3)
--   • tournament_match_games  — per-game scores within a match (M4)
--   • tournament_courts       — courts shared across the event's divisions
--
-- RLS mirrors event_sessions: organizer full access; members can read.
-- Denormalized counts on tournament_divisions are maintained by O(1) delta
-- triggers; the resulting UPDATE on the division row is the reliable Realtime
-- signal every member can SELECT (same strategy as event_sessions counts).
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── 1. tournament_divisions ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_divisions (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id              uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name                  text        NOT NULL,
  sport                 text        NOT NULL CHECK (sport IN ('badminton', 'pickleball')),
  discipline            text        NOT NULL CHECK (discipline IN ('singles', 'doubles', 'mixed')),
  skill_level           text        NOT NULL CHECK (skill_level IN ('A', 'B', 'C', 'D', 'E')),
  format                text        NOT NULL CHECK (format IN ('round_robin', 'single_elimination', 'pools_playoff')),
  scoring_config        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  team_size             integer     NOT NULL DEFAULT 1 CHECK (team_size BETWEEN 1 AND 2),
  entrant_cap           integer     CHECK (entrant_cap IS NULL OR entrant_cap > 0),
  pool_count            integer     CHECK (pool_count IS NULL OR pool_count > 0),
  advance_per_pool      integer     CHECK (advance_per_pool IS NULL OR advance_per_pool > 0),
  status                text        NOT NULL DEFAULT 'setup'
                        CHECK (status IN ('setup', 'registration', 'seeded', 'in_progress', 'completed')),
  bracket_generated_at  timestamptz,
  entrant_count         integer     NOT NULL DEFAULT 0,
  match_count           integer     NOT NULL DEFAULT 0,
  completed_match_count integer     NOT NULL DEFAULT 0,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, name)
);

ALTER TABLE tournament_divisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_divisions
  USING (
    EXISTS (SELECT 1 FROM events WHERE id = tournament_divisions.event_id AND created_by = auth.uid())
  );

CREATE POLICY "members can read divisions" ON tournament_divisions
  FOR SELECT USING (auth_user_is_event_member(tournament_divisions.event_id));

CREATE INDEX IF NOT EXISTS idx_tournament_divisions_event ON tournament_divisions(event_id);

-- ─── 2. tournament_entrants ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_entrants (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  division_id     uuid        NOT NULL REFERENCES tournament_divisions(id) ON DELETE CASCADE,
  team_name       text        NOT NULL,
  player1_user_id uuid        REFERENCES auth.users(id),
  player1_name    text        NOT NULL,
  player2_user_id uuid        REFERENCES auth.users(id),
  player2_name    text,
  seed            integer,
  pool_id         text,
  status          text        NOT NULL DEFAULT 'registered'
                  CHECK (status IN ('registered', 'checked_in', 'withdrawn')),
  registered_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tournament_entrants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_entrants
  USING (
    EXISTS (
      SELECT 1 FROM tournament_divisions d
      JOIN events e ON e.id = d.event_id
      WHERE d.id = tournament_entrants.division_id AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "members can read entrants" ON tournament_entrants
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournament_divisions d
      WHERE d.id = tournament_entrants.division_id
        AND auth_user_is_event_member(d.event_id)
    )
  );

CREATE INDEX IF NOT EXISTS idx_tournament_entrants_division ON tournament_entrants(division_id);

-- ─── 3. tournament_matches ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_matches (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  division_id       uuid        NOT NULL REFERENCES tournament_divisions(id) ON DELETE CASCADE,
  bracket_type      text        NOT NULL DEFAULT 'winners' CHECK (bracket_type IN ('pool', 'winners')),
  round_number      integer     NOT NULL DEFAULT 1,
  match_number      integer     NOT NULL DEFAULT 1,
  pool_id           text,
  entrant1_id       uuid        REFERENCES tournament_entrants(id) ON DELETE SET NULL,
  entrant2_id       uuid        REFERENCES tournament_entrants(id) ON DELETE SET NULL,
  winner_entrant_id uuid        REFERENCES tournament_entrants(id) ON DELETE SET NULL,
  next_match_id     uuid        REFERENCES tournament_matches(id) ON DELETE SET NULL,
  next_match_slot   integer     CHECK (next_match_slot IS NULL OR next_match_slot IN (1, 2)),
  court_id          uuid,
  status            text        NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'scheduled', 'in_progress', 'completed', 'bye', 'walkover')),
  scheduled_order   integer,
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tournament_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_matches
  USING (
    EXISTS (
      SELECT 1 FROM tournament_divisions d
      JOIN events e ON e.id = d.event_id
      WHERE d.id = tournament_matches.division_id AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "members can read matches" ON tournament_matches
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournament_divisions d
      WHERE d.id = tournament_matches.division_id
        AND auth_user_is_event_member(d.event_id)
    )
  );

CREATE INDEX IF NOT EXISTS idx_tournament_matches_division ON tournament_matches(division_id);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_court ON tournament_matches(court_id);

-- ─── 4. tournament_match_games ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_match_games (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id          uuid        NOT NULL REFERENCES tournament_matches(id) ON DELETE CASCADE,
  game_number       integer     NOT NULL,
  entrant1_score    integer     NOT NULL DEFAULT 0,
  entrant2_score    integer     NOT NULL DEFAULT 0,
  winner_entrant_id uuid        REFERENCES tournament_entrants(id) ON DELETE SET NULL,
  UNIQUE (match_id, game_number)
);

ALTER TABLE tournament_match_games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_match_games
  USING (
    EXISTS (
      SELECT 1 FROM tournament_matches m
      JOIN tournament_divisions d ON d.id = m.division_id
      JOIN events e ON e.id = d.event_id
      WHERE m.id = tournament_match_games.match_id AND e.created_by = auth.uid()
    )
  );

CREATE POLICY "members can read games" ON tournament_match_games
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tournament_matches m
      JOIN tournament_divisions d ON d.id = m.division_id
      WHERE m.id = tournament_match_games.match_id
        AND auth_user_is_event_member(d.event_id)
    )
  );

CREATE INDEX IF NOT EXISTS idx_tournament_match_games_match ON tournament_match_games(match_id);

-- ─── 5. tournament_courts ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_courts (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name             text        NOT NULL,
  status           text        NOT NULL DEFAULT 'available'
                   CHECK (status IN ('available', 'in_use', 'closed')),
  current_match_id uuid        REFERENCES tournament_matches(id) ON DELETE SET NULL,
  sort_order       integer     NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tournament_courts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "organizer full access" ON tournament_courts
  USING (
    EXISTS (SELECT 1 FROM events WHERE id = tournament_courts.event_id AND created_by = auth.uid())
  );

CREATE POLICY "members can read courts" ON tournament_courts
  FOR SELECT USING (auth_user_is_event_member(tournament_courts.event_id));

CREATE INDEX IF NOT EXISTS idx_tournament_courts_event ON tournament_courts(event_id);

-- Wire the deferred court FK on matches now that tournament_courts exists.
ALTER TABLE tournament_matches
  ADD CONSTRAINT tournament_matches_court_id_fkey
  FOREIGN KEY (court_id) REFERENCES tournament_courts(id) ON DELETE SET NULL;

-- ─── 6. Denormalized-count triggers (O(1) deltas) ───────────────────────────

-- entrant_count: count non-withdrawn entrants per division.
CREATE OR REPLACE FUNCTION public._update_division_entrant_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_division_id uuid;
BEGIN
  v_division_id := COALESCE(NEW.division_id, OLD.division_id);

  UPDATE tournament_divisions SET
    entrant_count = entrant_count
      + (CASE WHEN TG_OP <> 'DELETE' AND NEW.status <> 'withdrawn' THEN 1 ELSE 0 END)
      - (CASE WHEN TG_OP <> 'INSERT' AND OLD.status <> 'withdrawn' THEN 1 ELSE 0 END)
  WHERE id = v_division_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_division_entrant_count ON tournament_entrants;
CREATE TRIGGER trg_division_entrant_count
AFTER INSERT OR UPDATE OF status OR DELETE ON tournament_entrants
FOR EACH ROW EXECUTE FUNCTION public._update_division_entrant_count();

-- match_count + completed_match_count per division.
CREATE OR REPLACE FUNCTION public._update_division_match_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_division_id uuid;
BEGIN
  v_division_id := COALESCE(NEW.division_id, OLD.division_id);

  UPDATE tournament_divisions SET
    match_count = match_count
      + (CASE WHEN TG_OP = 'INSERT' THEN 1 ELSE 0 END)
      - (CASE WHEN TG_OP = 'DELETE' THEN 1 ELSE 0 END),
    completed_match_count = completed_match_count
      + (CASE WHEN TG_OP <> 'DELETE' AND NEW.status = 'completed' THEN 1 ELSE 0 END)
      - (CASE WHEN TG_OP <> 'INSERT' AND OLD.status = 'completed' THEN 1 ELSE 0 END)
  WHERE id = v_division_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_division_match_counts ON tournament_matches;
CREATE TRIGGER trg_division_match_counts
AFTER INSERT OR UPDATE OF status OR DELETE ON tournament_matches
FOR EACH ROW EXECUTE FUNCTION public._update_division_match_counts();

-- ─── 7. Realtime ────────────────────────────────────────────────────────────
-- REPLICA IDENTITY FULL so DELETE payloads carry the parent ids the Flutter
-- provider needs to route the change to the right cache.
ALTER TABLE tournament_divisions   REPLICA IDENTITY FULL;
ALTER TABLE tournament_entrants    REPLICA IDENTITY FULL;
ALTER TABLE tournament_matches     REPLICA IDENTITY FULL;
ALTER TABLE tournament_match_games REPLICA IDENTITY FULL;
ALTER TABLE tournament_courts      REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE tournament_divisions;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_entrants;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_match_games;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_courts;
