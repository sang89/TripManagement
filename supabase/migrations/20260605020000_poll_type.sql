-- Distinguish restaurant polls from general polls.
ALTER TABLE event_polls ADD COLUMN poll_type text NOT NULL DEFAULT 'general';

-- At most one restaurant poll per event (enforced at DB level).
CREATE UNIQUE INDEX event_polls_one_restaurant_per_event
  ON event_polls(event_id) WHERE poll_type = 'restaurant';

-- Any event member can create a restaurant poll; only the organizer can create general polls.
DROP POLICY IF EXISTS "polls_organiser_insert" ON event_polls;
CREATE POLICY "polls_insert" ON event_polls
  FOR INSERT WITH CHECK (
    auth.uid() = created_by AND
    auth_user_is_event_member(event_id) AND
    (
      poll_type = 'restaurant'
      OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
    )
  );
