CREATE TABLE event_poll_reactions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  option_id  uuid NOT NULL REFERENCES event_poll_options(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id),
  emoji      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT poll_reactions_one_per_emoji UNIQUE (option_id, user_id, emoji)
);

ALTER TABLE event_poll_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "poll_reactions_select" ON event_poll_reactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_poll_options epo
      JOIN event_polls ep ON ep.id = epo.poll_id
      WHERE epo.id = option_id AND auth_user_is_event_member(ep.event_id)
    )
  );

CREATE POLICY "poll_reactions_member_insert" ON event_poll_reactions
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM event_poll_options epo
      JOIN event_polls ep ON ep.id = epo.poll_id
      WHERE epo.id = option_id AND auth_user_is_event_member(ep.event_id)
    )
  );

CREATE POLICY "poll_reactions_own_delete" ON event_poll_reactions
  FOR DELETE USING (user_id = auth.uid());

ALTER PUBLICATION supabase_realtime ADD TABLE event_poll_reactions;
ALTER TABLE event_poll_reactions REPLICA IDENTITY FULL;
