create table if not exists transaction_labels (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade not null,
  name       text not null,
  color      text not null,
  icon       text not null,
  created_at timestamptz not null default now()
);
alter table transaction_labels enable row level security;
create policy "Users manage own labels"
  on transaction_labels for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create index if not exists transaction_labels_user_id_idx on transaction_labels (user_id);

alter table financial_transactions
  add column if not exists label_ids text[] not null default '{}';
alter table transaction_groups
  add column if not exists label_ids text[] not null default '{}';
