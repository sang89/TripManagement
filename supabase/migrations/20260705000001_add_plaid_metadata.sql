-- Store the full raw Plaid transaction object so the review screen can
-- surface all available metadata without repeated API calls.
alter table financial_transactions
  add column if not exists plaid_metadata jsonb;
