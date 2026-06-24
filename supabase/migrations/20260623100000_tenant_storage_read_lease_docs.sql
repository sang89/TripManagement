-- Allow linked tenants to SELECT (and generate signed URLs for) their own
-- lease document files. The storage path is {landlordUid}/{leaseId}/{fileId}.ext,
-- so (storage.foldername(name))[2] extracts the leaseId segment.
-- is_active_tenant_user is SECURITY DEFINER so it reads tenant_links without
-- triggering recursive policy evaluation.
create policy "Tenants can read own lease doc files"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'lease-documents'
    and (storage.foldername(name))[2] in (
      select l.id::text
      from leases l
      where is_active_tenant_user(l.tenant_id)
    )
  );
