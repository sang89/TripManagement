-- Fix trip_members RLS so invitees can see all members and send invites.
--
-- Problem 1 (visibility):
--   The original trip_members_select policy only lets you see your OWN row
--   (or all rows if you are the organizer).  An invitee loading a trip with
--   .select('*, trip_members(*)') only gets back their own member row — the
--   organizer and other members are invisible.
--
-- Problem 2 (insert):
--   trip_members_insert was organizer-only, so accepted invitees had no way
--   to invite additional people to a trip they belong to.

-- ── Fix 1: all members / pending invitees can read all member rows ─────────────
drop policy if exists "trip_members_select" on trip_members;
create policy "trip_members_select" on trip_members for select using (
  -- organizer sees every row
  trip_id in (select id from trips where created_by = auth.uid())
  -- accepted member sees every row in their trips
  or auth_user_is_trip_member(trip_id)
  -- pending invitee can see member rows (so they know who invited them)
  or auth_user_has_pending_invite(trip_id)
);

-- ── Fix 2: accepted members can also add new members ─────────────────────────
drop policy if exists "trip_members_insert" on trip_members;
create policy "trip_members_insert" on trip_members for insert with check (
  -- organizer
  trip_id in (select id from trips where created_by = auth.uid())
  -- any accepted member of the trip
  or auth_user_is_trip_member(trip_id)
);
