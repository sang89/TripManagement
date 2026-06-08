CREATE TABLE event_message_reactions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES event_messages(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id),
  emoji      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT msg_reactions_one_per_emoji UNIQUE (message_id, user_id, emoji)
);

ALTER TABLE event_message_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "msg_reactions_select" ON event_message_reactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_messages em
      WHERE em.id = message_id AND auth_user_is_event_member(em.event_id)
    )
  );

CREATE POLICY "msg_reactions_member_insert" ON event_message_reactions
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM event_messages em
      WHERE em.id = message_id AND auth_user_is_event_member(em.event_id)
    )
  );

CREATE POLICY "msg_reactions_own_delete" ON event_message_reactions
  FOR DELETE USING (user_id = auth.uid());

ALTER PUBLICATION supabase_realtime ADD TABLE event_message_reactions;
ALTER TABLE event_message_reactions REPLICA IDENTITY FULL;
