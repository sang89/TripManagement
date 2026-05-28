alter table financial_transactions
  add column if not exists vendor text,
  add column if not exists payment_method text;
