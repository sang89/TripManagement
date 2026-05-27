-- Fix infinite recursion in RLS policies.
--
-- Root cause: trips_select queries trip_members (to check membership),
-- and trip_members_select queries trips (to check organizer), creating a cycle.
--
-- Fix: a security definer function reads trip_members WITHOUT triggering RLS,
-- so trips_select can safely call it without re-entering trip_members policies.

create or replace function auth_user_is_trip_member(p_trip_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from trip_members
    where trip_id = p_trip_id and user_id = auth.uid()
  );
$$;

-- Re-create trips_select using the security definer function
drop policy if exists "trips_select" on trips;
create policy "trips_select" on trips for select using (
  created_by = auth.uid()
  or auth_user_is_trip_member(id)
);

-- Re-create trip_stops policies using the same function
drop policy if exists "trip_stops_select" on trip_stops;
drop policy if exists "trip_stops_insert" on trip_stops;
drop policy if exists "trip_stops_update" on trip_stops;
drop policy if exists "trip_stops_delete" on trip_stops;

create policy "trip_stops_select" on trip_stops for select using (
  trip_id in (select id from trips where created_by = auth.uid())
  or auth_user_is_trip_member(trip_id)
);
create policy "trip_stops_insert" on trip_stops for insert with check (
  trip_id in (select id from trips where created_by = auth.uid())
  or auth_user_is_trip_member(trip_id)
);
create policy "trip_stops_update" on trip_stops for update using (
  trip_id in (select id from trips where created_by = auth.uid())
  or auth_user_is_trip_member(trip_id)
);
create policy "trip_stops_delete" on trip_stops for delete using (
  trip_id in (select id from trips where created_by = auth.uid())
  or auth_user_is_trip_member(trip_id)
);
