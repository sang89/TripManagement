-- Redesign bring list: drop quantity/claim, add note/assigned_to_name

ALTER TABLE event_bring_list_items
  DROP COLUMN IF EXISTS quantity,
  DROP COLUMN IF EXISTS claimed_by,
  DROP COLUMN IF EXISTS claimed_at,
  ADD COLUMN IF NOT EXISTS note text,
  ADD COLUMN IF NOT EXISTS assigned_to_name text;

-- Replace claim-ownership UPDATE policy with a simple member-can-update policy
DROP POLICY IF EXISTS "bring_member_claim" ON event_bring_list_items;

CREATE POLICY "bring_member_update" ON event_bring_list_items
  FOR UPDATE USING (auth_user_is_event_member(event_id));
