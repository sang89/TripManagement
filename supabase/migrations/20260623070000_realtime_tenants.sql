-- Stream the tenants table over Realtime so a landlord sees a newly-joined
-- tenant appear (and tenant-side record changes) live, without a reload.
alter table tenants replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'tenants') then
    alter publication supabase_realtime add table tenants;
  end if;
end $$;
