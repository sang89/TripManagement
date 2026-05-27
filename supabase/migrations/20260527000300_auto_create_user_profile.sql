-- Automatically create a user_profiles row whenever a new user signs up.
-- Pulls full_name from raw_user_meta_data if the client passed it during signUp
-- (AuthProvider passes data: {'name': name}).
-- ON CONFLICT DO NOTHING is safe for existing users who already have a row.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (user_id, full_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'full_name',
      ''
    )
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: create rows for any existing auth users who have none yet.
insert into public.user_profiles (user_id)
select au.id
from auth.users au
where not exists (
  select 1 from public.user_profiles up where up.user_id = au.id
);
