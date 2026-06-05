-- Enable Realtime for poll tables so votes and new options propagate live.
ALTER PUBLICATION supabase_realtime ADD TABLE event_polls;
ALTER PUBLICATION supabase_realtime ADD TABLE event_poll_options;
ALTER PUBLICATION supabase_realtime ADD TABLE event_poll_votes;

-- Full row in DELETE payloads so the subscriber can identify which poll to refetch.
ALTER TABLE event_poll_votes   REPLICA IDENTITY FULL;
ALTER TABLE event_poll_options REPLICA IDENTITY FULL;
