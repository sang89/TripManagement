-- Replace the `social` event type with `tournament`.
--
-- We use ALTER TYPE ... RENAME VALUE rather than a full enum rebuild. Renaming
-- the value in place:
--   * removes 'social' from the event_type enum,
--   * adds 'tournament' (occupying the renamed slot),
--   * automatically relabels every existing events row whose event_type was
--     'social' to 'tournament' (no data UPDATE needed — it is the same
--     underlying enum value, just a new label),
--   * leaves every function that references the event_type type (create_event,
--     get_event_by_invite_code, the get_events_* list RPCs, etc.) valid —
--     their stored enum defaults deparse to the new label, so no DROP/CREATE of
--     those functions is required.
--
-- RENAME VALUE is safe inside a transaction (unlike ADD VALUE on older
-- Postgres). This DB is shared with PropertyManagement, but event_type is
-- TripManagement-specific, so this migration is NOT copied there.
ALTER TYPE event_type RENAME VALUE 'social' TO 'tournament';

-- The events.event_type column default was 'social'; after the rename it would
-- resolve to 'tournament'. New events should default to 'trip' (the app always
-- passes an explicit type, but keep the schema default sensible).
ALTER TABLE events ALTER COLUMN event_type SET DEFAULT 'trip';
