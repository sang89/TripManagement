-- Allow multiple votes per user per poll (needed for restaurant pitch auto-vote).
-- A user can vote for several options but cannot vote for the same option twice.
ALTER TABLE event_poll_votes DROP CONSTRAINT event_poll_votes_poll_id_user_id_key;
ALTER TABLE event_poll_votes ADD CONSTRAINT event_poll_votes_poll_option_user_key
  UNIQUE (poll_id, option_id, user_id);

-- Allow any event member to add poll options (previously organizer-only,
-- but the Cravings feature lets any member pitch restaurants).
DROP POLICY IF EXISTS "poll_options_organiser_insert" ON event_poll_options;
CREATE POLICY "poll_options_member_insert" ON event_poll_options
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM event_polls p
      WHERE p.id = poll_id AND auth_user_is_event_member(p.event_id)
    )
  );
