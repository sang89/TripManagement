CREATE TABLE event_bring_list_items (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  label           text NOT NULL,
  quantity        int  NOT NULL DEFAULT 1,
  claimed_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  claimed_by_name text,
  claimed_at      timestamptz,
  created_by      uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE event_bring_list_items ENABLE ROW LEVEL SECURITY;

-- Any event member can read items.
CREATE POLICY "bring_items_select" ON event_bring_list_items
  FOR SELECT USING (auth_user_is_event_member(event_id));

-- Only the event organiser can add or remove items.
CREATE POLICY "bring_items_organiser_insert" ON event_bring_list_items
  FOR INSERT WITH CHECK (
    auth.uid() = created_by AND
    EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

CREATE POLICY "bring_items_organiser_delete" ON event_bring_list_items
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- Any member can claim or unclaim an item.
CREATE POLICY "bring_items_member_claim" ON event_bring_list_items
  FOR UPDATE USING (auth_user_is_event_member(event_id))
  WITH CHECK (auth_user_is_event_member(event_id));
