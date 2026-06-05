ALTER TABLE event_bring_list_items
  ADD COLUMN IF NOT EXISTS is_done boolean NOT NULL DEFAULT false;
