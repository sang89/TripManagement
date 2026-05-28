create table if not exists user_payment_methods (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null,
  created_at  timestamptz not null default now()
);

alter table user_payment_methods enable row level security;

create policy "Users can manage their own payment methods"
  on user_payment_methods
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
