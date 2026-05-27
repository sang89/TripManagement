-- Add invitation status to trip_members.
-- Existing rows (already accepted implicitly) default to 'accepted'.
-- New linked-account invites are inserted with 'pending' and must be
-- accepted or declined by the invitee before they gain trip access.

-- 1. Status column
alter table trip_members
  add column if not exists status text not null default 'accepted';

alter table trip_members
  add constraint trip_members_status_check
  check (status in ('pending', 'accepted', 'declined'));

-- 2. Update auth_user_is_trip_member() — only accepted members count.
--    This function is used by trips_select / trip_stops_* policies to
--    avoid RLS recursion (defined in 20260526130000_fix_rls_recursion.sql).
create or replace function public.auth_user_is_trip_member(p_trip_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from trip_members
    where trip_id = p_trip_id
      and user_id = auth.uid()
      and status = 'accepted'
  );
$$;

-- 3. New helper: pending invite check.
--    Lets an invitee SELECT the trip so they can see its title / details
--    when deciding whether to accept.
create or replace function public.auth_user_has_pending_invite(p_trip_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from trip_members
    where trip_id = p_trip_id
      and user_id = auth.uid()
      and status = 'pending'
  );
$$;

-- 4. Update trips_select to include pending invitees (read-only — they
--    cannot update/delete because those policies still check created_by).
drop policy if exists "trips_select" on trips;
create policy "trips_select" on trips for select using (
  created_by = auth.uid()
  or auth_user_is_trip_member(id)
  or auth_user_has_pending_invite(id)
);

-- 5. Allow invitees to update their own row (to accept or decline).
--    The with check clause prevents them changing anything except their own row.
create policy "trip_members_update_own_status" on trip_members
  for update
  using  (user_id = auth.uid())
  with check (user_id = auth.uid());
