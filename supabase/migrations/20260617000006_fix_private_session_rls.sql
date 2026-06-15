-- B14: Members could read private (is_public = false) sessions via the
-- "members can read sessions" policy because it didn't check is_public.
-- Organizers always see all sessions on their own events.
-- The recursion-safe helper function pattern from 20260611000004 is preserved.

DROP POLICY IF EXISTS "members can read sessions" ON event_sessions;

CREATE POLICY "members can read sessions" ON event_sessions
  FOR SELECT USING (
    -- Organizer always sees all sessions (including private ones).
    EXISTS (
      SELECT 1 FROM events
      WHERE id = event_sessions.event_id
        AND created_by = auth.uid()
    )
    OR
    -- Members only see public sessions.
    (
      event_sessions.is_public = true
      AND EXISTS (
        SELECT 1 FROM event_guests
        WHERE event_id = event_sessions.event_id
          AND user_id  = auth.uid()
          AND status NOT IN ('left', 'declined')
      )
    )
  );
