-- Refactor: introduce a proper leases table so tenants can have multiple leases.
-- Migrates flat lease columns off the tenants table.

-- 1. Create leases table
create table leases (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid references tenants(id) on delete cascade not null,
  monthly_rent     numeric not null default 0,
  security_deposit numeric not null default 0,
  lease_start      date,
  lease_end        date,
  move_in_date     date,
  move_out_date    date,
  notes            text not null default '',
  created_at       timestamptz not null default now()
);

alter table leases enable row level security;

create policy "Users manage own leases"
  on leases
  using (
    tenant_id in (
      select id from tenants where property_id in (
        select id from properties where user_id = auth.uid()
      )
    )
  );

-- 2. Migrate existing tenant flat fields into leases
insert into leases (id, tenant_id, monthly_rent, security_deposit,
                    lease_start, lease_end, move_in_date, move_out_date)
select
  gen_random_uuid(),
  id,
  monthly_rent,
  security_deposit,
  lease_start,
  lease_end,
  move_in_date,
  move_out_date
from tenants
where
  monthly_rent > 0
  or lease_start  is not null
  or lease_end    is not null
  or move_in_date is not null
  or move_out_date is not null;

-- 3. Recreate lease_documents with lease_id instead of tenant_id.
-- This table was added in the immediately preceding migration and has no
-- production data, so we drop and recreate cleanly.
drop policy if exists "Users manage own lease documents" on lease_documents;
drop table if exists lease_documents;

create table lease_documents (
  id           uuid primary key default gen_random_uuid(),
  lease_id     uuid references leases(id) on delete cascade not null,
  storage_url  text not null,
  file_name    text not null default '',
  created_at   timestamptz not null default now()
);

alter table lease_documents enable row level security;

create policy "Users manage own lease documents"
  on lease_documents
  using (
    lease_id in (
      select l.id from leases l
      join tenants  t on t.id = l.tenant_id
      join properties p on p.id = t.property_id
      where p.user_id = auth.uid()
    )
  );

-- Storage bucket and policy are unchanged (same bucket, same uid prefix check)

-- 4. Drop flat lease columns from tenants
alter table tenants
  drop column if exists monthly_rent,
  drop column if exists security_deposit,
  drop column if exists lease_start,
  drop column if exists lease_end,
  drop column if exists move_in_date,
  drop column if exists move_out_date;
