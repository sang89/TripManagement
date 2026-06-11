-- Indexes to support scalable queries as session + roster counts grow.

-- _fetchMySessionStatuses: WHERE user_id = ? AND session_id IN (...)
-- rsvp_session duplicate check: WHERE session_id = ? AND user_id = ?
-- cancel_session_signup: WHERE id = ? AND user_id = ?
CREATE INDEX IF NOT EXISTS idx_session_roster_user_session
  ON event_session_roster(user_id, session_id)
  WHERE user_id IS NOT NULL;

-- Partial index for signed_up_at ordering within a session (used by
-- the backfill migration ORDER BY signed_up_at to assign signup_order).
CREATE INDEX IF NOT EXISTS idx_session_roster_session_signedup
  ON event_session_roster(session_id, signed_up_at ASC);
