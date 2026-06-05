create table notifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  type         text not null check (type in ('lease_expiry', 'system')),
  title        text not null,
  body         text not null default '',
  reference_id text,
  metadata     jsonb,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

-- Prevent duplicate lease-expiry notifications for the same tenant
create unique index notifications_user_type_ref_idx
  on notifications (user_id, type, reference_id)
  where reference_id is not null;

alter table notifications enable row level security;

create policy "Users read own notifications"
  on notifications for select
  using (user_id = auth.uid());

create policy "Users insert own notifications"
  on notifications for insert
  with check (user_id = auth.uid());

create policy "Users update own notifications"
  on notifications for update
  using (user_id = auth.uid());

create policy "Users delete own notifications"
  on notifications for delete
  using (user_id = auth.uid());
