-- Allow tenants to delete their own requests only while still in a
-- cancellable state (requested or declined). Once a landlord has acknowledged
-- or started work, the tenant can no longer delete it.
create policy "tenant deletes own cancellable request"
  on tenant_requests for delete
  using (
    created_by = auth.uid()
    and status in ('requested', 'declined')
  );
