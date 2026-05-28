-- Change the leave mechanism from DELETE to UPDATE (status = 'left').
--
-- Why: deleting the row means other members lose any record of who left.
-- Keeping the row with status='left' lets the UI show "Left" on the member
-- tile, which makes the trip member list self-consistent for everyone.
--
-- Access: auth_user_is_trip_member() already requires status='accepted', so
-- a 'left' member has no read access to the trip — same effect as deletion.
--
-- The existing trip_members_update_own_status policy already lets a member
-- update their own row (used for accept/decline), so no new policy is needed.

alter table trip_members
  drop constraint if exists trip_members_status_check;

alter table trip_members
  add constraint trip_members_status_check
  check (status in ('pending', 'accepted', 'declined', 'left'));
