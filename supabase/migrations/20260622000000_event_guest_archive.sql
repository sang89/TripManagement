-- Per-user "Move to Past" archive flag on event_guests.
--
-- Each member (including the organizer, who is auto-added as a role='organizer'
-- guest row) has exactly one event_guests row per event. is_archived lets a user
-- move an event to their own Past tab without affecting other members' views.
--
-- No new RLS is needed: the existing UPDATE policy already lets a user update
-- their own row (user_id = auth.uid()). is_archived never touches `status`, so
-- the invite triggers (on_invite_inserted / on_member_reinvite_check) do not fire.
-- event_guests already has REPLICA IDENTITY FULL + Realtime, so the flag syncs
-- across the actor's own devices automatically.

ALTER TABLE event_guests
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
