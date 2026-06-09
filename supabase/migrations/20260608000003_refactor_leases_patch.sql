-- Idempotent patch: complete the leases refactor in case 000002 partially applied.

-- Ensure lease_documents uses lease_id (drop tenant_id version if it exists)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'lease_documents' and column_name = 'tenant_id'
  ) then
    -- Recreate table with correct FK
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
  end if;
end $$;

-- Drop flat lease columns from tenants if they still exist
alter table tenants drop column if exists monthly_rent;
alter table tenants drop column if exists security_deposit;
alter table tenants drop column if exists lease_start;
alter table tenants drop column if exists lease_end;
alter table tenants drop column if exists move_in_date;
alter table tenants drop column if exists move_out_date;
