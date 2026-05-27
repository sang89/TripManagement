-- trips
create table trips (
  id             uuid primary key default gen_random_uuid(),
  created_by     uuid not null references auth.users on delete cascade,
  title          text not null default '',
  destination    text not null default '',
  destination_lat double precision,
  destination_lng double precision,
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  notes          text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- trip_members
create table trip_members (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references trips on delete cascade,
  user_id      uuid references auth.users on delete set null,
  display_name text not null,
  email        text,
  role         text not null default 'member',
  created_at   timestamptz not null default now()
);

-- trip_stops
create table trip_stops (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid not null references trips on delete cascade,
  title       text not null default '',
  address     text not null default '',
  arrive_at   timestamptz,
  depart_at   timestamptz,
  notes       text not null default '',
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

-- updated_at trigger for trips
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trips_updated_at
  before update on trips
  for each row execute function set_updated_at();

-- grants
grant select, insert, update, delete on trips        to authenticated, service_role;
grant select, insert, update, delete on trip_members to authenticated, service_role;
grant select, insert, update, delete on trip_stops   to authenticated, service_role;

-- RLS
alter table trips        enable row level security;
alter table trip_members enable row level security;
alter table trip_stops   enable row level security;

-- trips: members can read
create policy "trips_select" on trips for select using (
  created_by = auth.uid()
  or exists (
    select 1 from trip_members
    where trip_members.trip_id = trips.id
      and trip_members.user_id = auth.uid()
  )
);
create policy "trips_insert" on trips for insert with check (created_by = auth.uid());
create policy "trips_update" on trips for update using (created_by = auth.uid());
create policy "trips_delete" on trips for delete using (created_by = auth.uid());

-- trip_members: own row or organizer can see all
create policy "trip_members_select" on trip_members for select using (
  user_id = auth.uid()
  or trip_id in (select id from trips where created_by = auth.uid())
);
create policy "trip_members_insert" on trip_members for insert with check (
  trip_id in (select id from trips where created_by = auth.uid())
);
create policy "trip_members_delete" on trip_members for delete using (
  trip_id in (select id from trips where created_by = auth.uid())
);

-- trip_stops: all trip members can read and write
create policy "trip_stops_select" on trip_stops for select using (
  trip_id in (
    select id from trips
    where created_by = auth.uid()
       or exists (
         select 1 from trip_members
         where trip_members.trip_id = trips.id
           and trip_members.user_id = auth.uid()
       )
  )
);
create policy "trip_stops_insert" on trip_stops for insert with check (
  trip_id in (
    select id from trips
    where created_by = auth.uid()
       or exists (
         select 1 from trip_members
         where trip_members.trip_id = trips.id
           and trip_members.user_id = auth.uid()
       )
  )
);
create policy "trip_stops_update" on trip_stops for update using (
  trip_id in (
    select id from trips
    where created_by = auth.uid()
       or exists (
         select 1 from trip_members
         where trip_members.trip_id = trips.id
           and trip_members.user_id = auth.uid()
       )
  )
);
create policy "trip_stops_delete" on trip_stops for delete using (
  trip_id in (
    select id from trips
    where created_by = auth.uid()
       or exists (
         select 1 from trip_members
         where trip_members.trip_id = trips.id
           and trip_members.user_id = auth.uid()
       )
  )
);
