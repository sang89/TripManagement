-- The AI review gate saves requests as 'declined' before they reach the
-- landlord. The previous INSERT policy only allowed status='requested', which
-- blocked this. Widen it to also allow 'declined' so the tenant can record
-- AI-rejected requests (landlord sees them for audit / override).
drop policy if exists "tenant inserts request for their property" on tenant_requests;

create policy "tenant inserts request for their property"
  on tenant_requests for insert
  with check (
    tenant_can_access_property(property_id)
    and created_by = auth.uid()
    and status in ('requested', 'declined')
  );
