-- Enable realtime for event_bring_list_items.
-- event_photos and event_expenses are already in the publication (20260602000300).
-- bring_list_items was missing.

ALTER TABLE event_bring_list_items REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE event_bring_list_items;
