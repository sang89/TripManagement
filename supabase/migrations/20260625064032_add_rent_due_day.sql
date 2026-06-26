-- Add rent_due_day to leases: day of month (1–28) on which rent is due each month.
-- Capped at 28 so it's valid in every month (Feb). When generating payments,
-- the provider clamps to the last day of the month if needed.
ALTER TABLE leases
  ADD COLUMN IF NOT EXISTS rent_due_day integer NOT NULL DEFAULT 1
  CHECK (rent_due_day BETWEEN 1 AND 28);

-- Add auto_generated flag so we can distinguish auto-created rows from
-- landlord-manually-created ones (useful for future re-generation logic).
ALTER TABLE rent_payments
  ADD COLUMN IF NOT EXISTS auto_generated boolean NOT NULL DEFAULT false;

-- Add unique constraint so upsert-on-conflict works correctly.
-- Remove any accidental duplicate (tenant_id, due_date) pairs first — keep
-- the most recently created row for each pair.
DELETE FROM rent_payments rp
WHERE id NOT IN (
  SELECT DISTINCT ON (tenant_id, due_date) id
  FROM rent_payments
  ORDER BY tenant_id, due_date, created_at DESC
);

ALTER TABLE rent_payments
  ADD CONSTRAINT rent_payments_tenant_due_date_key
  UNIQUE (tenant_id, due_date);
