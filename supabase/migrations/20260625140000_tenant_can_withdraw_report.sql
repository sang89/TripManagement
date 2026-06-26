-- Allow tenants to withdraw a self-reported payment, reverting it to 'pending'.
-- The existing policy only allowed WITH CHECK status = 'tenant_reported'.
-- We extend it to also allow status = 'pending' with no reported_by (the
-- cleared state produced by withdrawReportedPayment).

DROP POLICY IF EXISTS "linked tenant updates own self-report" ON rent_payments;

CREATE POLICY "linked tenant updates own self-report"
  ON rent_payments FOR UPDATE
  USING (
    is_active_tenant_user(tenant_id)
    AND status IN ('pending','overdue','tenant_reported','rejected')
  )
  WITH CHECK (
    is_active_tenant_user(tenant_id)
    AND (
      -- Normal self-report: move to tenant_reported, caller must be the reporter.
      (status = 'tenant_reported' AND reported_by = auth.uid())
      OR
      -- Withdrawal: revert to pending, all reported fields must be cleared.
      (status = 'pending' AND reported_by IS NULL AND reported_amount IS NULL)
    )
  );
