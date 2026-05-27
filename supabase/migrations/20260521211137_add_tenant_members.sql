-- tenant_members: family/household members belonging to a primary tenant
create table tenant_members (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid references tenants(id) on delete cascade not null,
  name         text not null default '',
  relationship text not null default 'other', -- spouse|partner|child|parent|sibling|other
  notes        text not null default '',
  created_at   timestamptz not null default now()
);

alter table tenant_members enable row level security;

create policy "Users can manage their own tenant members"
  on tenant_members
  using (
    tenant_id in (
      select id from tenants where property_id in (
        select id from properties where user_id = auth.uid()
      )
    )
  );
