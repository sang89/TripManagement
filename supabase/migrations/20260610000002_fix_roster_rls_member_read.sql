-- Allow any event member (accepted or invited) to read all roster entries for
-- sessions of that event. Previously only the organizer and the roster member
-- themselves could read rows, so non-signed-up invitees saw an empty roster
-- while the going_count on event_sessions correctly showed the real number.
CREATE POLICY "event member reads roster" ON event_session_roster
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_sessions es
      JOIN event_guests eg ON eg.event_id = es.event_id
      WHERE es.id = event_session_roster.session_id
        AND eg.user_id = auth.uid()
    )
  );
