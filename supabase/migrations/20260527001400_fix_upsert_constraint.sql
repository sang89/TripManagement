-- PostgREST's upsert ON CONFLICT target requires a real unique CONSTRAINT,
-- not a partial unique INDEX. Replace the partial index from 20260527001200
-- with a proper constraint.
--
-- PostgreSQL treats NULL as distinct in unique constraints, so multiple guest
-- rows (user_id IS NULL) for the same trip are still allowed — only linked
-- users (user_id IS NOT NULL) are deduplicated per trip.

-- 1. Remove any duplicate linked-user rows left over from before this fix
--    (keep the newest row per trip+user pair).
DELETE FROM trip_members a
USING trip_members b
WHERE a.user_id IS NOT NULL
  AND a.trip_id = b.trip_id
  AND a.user_id = b.user_id
  AND a.id <> b.id
  AND a.created_at < b.created_at;

-- 2. Drop the partial index (not usable by PostgREST for ON CONFLICT)
DROP INDEX IF EXISTS trip_members_trip_user_unique;

-- 3. Add a unique constraint that PostgREST can target
ALTER TABLE trip_members
  ADD CONSTRAINT trip_members_trip_user_unique
  UNIQUE (trip_id, user_id);
