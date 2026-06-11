-- Enable Realtime for signup session tables.
-- REPLICA IDENTITY FULL ensures DELETE payloads carry session_id so the
-- Flutter provider can route the change to the right event's cache.

ALTER TABLE event_sessions      REPLICA IDENTITY FULL;
ALTER TABLE event_session_roster REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE event_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE event_session_roster;
