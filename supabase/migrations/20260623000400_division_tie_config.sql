-- Team-division tie configuration (how a team-vs-team "tie" is played).
-- The column lives with the team-division config (M6); the tie behaviour
-- (sub-matches, pairing, scoring) is added in M7.
ALTER TABLE tournament_divisions
  ADD COLUMN IF NOT EXISTS tie_config jsonb;
