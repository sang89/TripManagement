-- Prevent duplicate bank transactions when Plaid resends the same transaction_id.
-- Partial index so manual transactions (external_id IS NULL) are unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS financial_transactions_external_id_unique
  ON financial_transactions (external_id)
  WHERE external_id IS NOT NULL;
