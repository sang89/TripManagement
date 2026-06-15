-- B2: Prevent duplicate (session_id, user_id) rows in event_session_roster.
-- The application-level duplicate check inside rsvp_session can be raced by
-- concurrent requests. A partial unique index at the DB level is the final guard.
-- WHERE user_id IS NOT NULL allows multiple anonymous (guest) rows per session.

-- Remove any pre-existing duplicates before adding the constraint
-- (keeps the row with the lowest created_at / earliest signup).
DELETE FROM event_session_roster a
USING event_session_roster b
WHERE a.session_id = b.session_id
  AND a.user_id    = b.user_id
  AND a.user_id IS NOT NULL
  AND a.signed_up_at > b.signed_up_at;

CREATE UNIQUE INDEX IF NOT EXISTS uq_session_roster_user
  ON event_session_roster(session_id, user_id)
  WHERE user_id IS NOT NULL;
