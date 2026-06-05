-- Prevent the same restaurant (by place_id) from appearing twice in one poll.
-- This enforces rule 4 at the DB level, independent of app-level cache checks.
CREATE UNIQUE INDEX IF NOT EXISTS event_poll_options_no_dup_place
  ON event_poll_options (poll_id, (place_metadata->>'place_id'))
  WHERE place_metadata IS NOT NULL
    AND (place_metadata->>'place_id') IS NOT NULL;
