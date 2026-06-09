-- Ensure leases table exists (idempotent) and add a user-visible name column.

create table if not exists leases (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid references tenants(id) on delete cascade not null,
  name             text not null default '',
  monthly_rent     numeric not null default 0,
  security_deposit numeric not null default 0,
  lease_start      date,
  lease_end        date,
  move_in_date     date,
  move_out_date    date,
  notes            text not null default '',
  created_at       timestamptz not null default now()
);

alter table leases add column if not exists name text not null default '';

alter table leases enable row level security;

drop policy if exists "Users manage own leases" on leases;
create policy "Users manage own leases"
  on leases
  using (
    tenant_id in (
      select id from tenants where property_id in (
        select id from properties where user_id = auth.uid()
      )
    )
  );

grant select, insert, update, delete on leases to authenticated;
