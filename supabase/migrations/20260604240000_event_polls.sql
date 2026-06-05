CREATE TABLE event_polls (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  question   text NOT NULL,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE event_poll_options (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id    uuid NOT NULL REFERENCES event_polls(id) ON DELETE CASCADE,
  text       text NOT NULL,
  sort_order int  NOT NULL DEFAULT 0
);

CREATE TABLE event_poll_votes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id    uuid NOT NULL REFERENCES event_polls(id) ON DELETE CASCADE,
  option_id  uuid NOT NULL REFERENCES event_poll_options(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (poll_id, user_id)
);

ALTER TABLE event_polls        ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_poll_votes   ENABLE ROW LEVEL SECURITY;

-- event_polls
CREATE POLICY "polls_select" ON event_polls
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "polls_organiser_insert" ON event_polls
  FOR INSERT WITH CHECK (
    auth.uid() = created_by AND
    EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

CREATE POLICY "polls_organiser_delete" ON event_polls
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- event_poll_options
CREATE POLICY "poll_options_select" ON event_poll_options
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_polls
      WHERE id = poll_id AND auth_user_is_event_member(event_id)
    )
  );

CREATE POLICY "poll_options_organiser_insert" ON event_poll_options
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM event_polls p
      JOIN events e ON e.id = p.event_id
      WHERE p.id = poll_id AND e.created_by = auth.uid()
    )
  );

-- event_poll_votes
CREATE POLICY "poll_votes_select" ON event_poll_votes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_polls
      WHERE id = poll_id AND auth_user_is_event_member(event_id)
    )
  );

CREATE POLICY "poll_votes_member_insert" ON event_poll_votes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM event_polls
      WHERE id = poll_id AND auth_user_is_event_member(event_id)
    )
  );

CREATE POLICY "poll_votes_own_delete" ON event_poll_votes
  FOR DELETE USING (user_id = auth.uid());
