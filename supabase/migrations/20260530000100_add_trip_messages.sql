-- Trip messages table: stores group chat messages for each trip.
-- All accepted members of a trip can read and post messages.
-- Messages are permanent (no UPDATE/DELETE for simplicity).

CREATE TABLE trip_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id    uuid NOT NULL REFERENCES trips(id)      ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content    text NOT NULL CHECK (char_length(content) > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE trip_messages ENABLE ROW LEVEL SECURITY;

-- Only accepted members of the trip can read messages.
CREATE POLICY trip_messages_select ON trip_messages FOR SELECT
  USING (auth_user_is_trip_member(trip_id));

-- Only accepted members can post, and only as themselves.
CREATE POLICY trip_messages_insert ON trip_messages FOR INSERT
  WITH CHECK (user_id = auth.uid() AND auth_user_is_trip_member(trip_id));

-- Include in Realtime so members receive new messages live.
ALTER PUBLICATION supabase_realtime ADD TABLE trip_messages;

ALTER TABLE trip_messages REPLICA IDENTITY FULL;

-- Index for efficient per-trip message listing (newest first).
CREATE INDEX trip_messages_trip_created ON trip_messages (trip_id, created_at DESC);
