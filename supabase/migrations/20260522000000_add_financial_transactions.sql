create table financial_transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete cascade not null,
  type         text not null check (type in ('income', 'expense')),
  category     text not null,
  amount       numeric(12, 2) not null check (amount >= 0),
  date         date not null,
  description  text,
  notes        text,
  property_id  uuid references properties(id) on delete set null,
  source_type  text,
  source_id    text,
  created_at   timestamptz not null default now()
);

alter table financial_transactions enable row level security;

create policy "Users manage own financial_transactions"
  on financial_transactions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index on financial_transactions (user_id);
create index on financial_transactions (date desc);
create index on financial_transactions (property_id);
create index on financial_transactions (source_type, source_id);
