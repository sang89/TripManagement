-- Stream tenant-portal tables over Supabase Realtime so landlord/tenant views
-- update live (links accepted, requests filed/answered, payments reported/
-- confirmed) without a manual reload. RLS still scopes which rows each client
-- receives. REPLICA IDENTITY FULL so UPDATE/DELETE payloads + column filters
-- work on all events.

alter table tenant_links    replica identity full;
alter table tenant_requests replica identity full;
alter table rent_payments   replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'tenant_links') then
    alter publication supabase_realtime add table tenant_links;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'tenant_requests') then
    alter publication supabase_realtime add table tenant_requests;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'rent_payments') then
    alter publication supabase_realtime add table rent_payments;
  end if;
end $$;
