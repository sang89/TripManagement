-- Make tournament division `sport` and `skill_level` free-form.
--
-- Organizers asked for the freedom to run any sport and any rating scheme, not
-- a fixed enum. Both columns are already plain text; we just drop the CHECK
-- constraints so any label is accepted. `discipline` (drives team size) and
-- `format` (drives the bracket algorithm) stay constrained — the engine depends
-- on them. `scoring_config` is JSONB and was already fully customizable.
ALTER TABLE tournament_divisions DROP CONSTRAINT IF EXISTS tournament_divisions_sport_check;
ALTER TABLE tournament_divisions DROP CONSTRAINT IF EXISTS tournament_divisions_skill_level_check;
