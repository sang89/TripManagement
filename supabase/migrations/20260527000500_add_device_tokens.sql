-- Stores FCM device tokens per user so the Edge Function can send
-- push notifications when a trip invitation is created.
-- One user may have multiple devices (phone + tablet), so we allow
-- multiple tokens per user keyed on (user_id, token).

create table if not exists public.device_tokens (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  token       text        not null,
  platform    text        not null check (platform in ('ios', 'android')),
  updated_at  timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.device_tokens enable row level security;

-- Users can only read/write their own tokens.
create policy "device_tokens_manage_own" on device_tokens
  using  (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.device_tokens to authenticated;
grant select, insert, update, delete on public.device_tokens to service_role;

-- Auto-update updated_at on token refresh.
create or replace function public.handle_device_token_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_device_token_updated_at
  before update on public.device_tokens
  for each row execute function public.handle_device_token_updated_at();
