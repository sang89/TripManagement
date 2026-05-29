create table if not exists transaction_groups (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete cascade not null,
  name         text not null,
  description  text,
  receipt_urls text[] not null default '{}',
  created_at   timestamptz not null default now()
);

alter table transaction_groups enable row level security;

create policy "Users manage own transaction_groups"
  on transaction_groups for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists transaction_groups_user_id_idx on transaction_groups (user_id);

alter table financial_transactions
  add column if not exists group_id uuid references transaction_groups(id) on delete set null;

create index if not exists financial_transactions_group_id_idx on financial_transactions (group_id);
