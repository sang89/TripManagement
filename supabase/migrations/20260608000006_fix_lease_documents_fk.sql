-- Fix: lease_documents still has tenant_id from the original migration.
-- Recreate it with the correct lease_id FK so the leases↔lease_documents
-- relationship is visible to PostgREST.

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

grant select, insert, update, delete on lease_documents to authenticated;
