-- Allow linked tenants to SELECT lease documents for their own leases.
-- The landlord policy (lease_id in landlord's leases) already exists; this
-- additive policy lets the tenant user see their own documents.
create policy "Tenants can read own lease documents"
  on lease_documents
  for select
  to authenticated
  using (
    lease_id in (
      select l.id from leases l
      where is_active_tenant_user(l.tenant_id)
    )
  );
