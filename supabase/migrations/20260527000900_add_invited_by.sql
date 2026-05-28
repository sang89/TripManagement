-- Track who invited whom in trip_members.
--
-- invited_by is set to auth.uid() of the user who called the addMember
-- insert.  The organizer's own row (inserted automatically on trip creation)
-- has invited_by = NULL.
--
-- on delete set null: if the inviter later leaves / is removed, the column
-- goes to NULL rather than cascading deletion of the invitee's row.

alter table trip_members
  add column if not exists invited_by uuid references auth.users on delete set null;
