-- RPC: find_user_by_contact
-- Allows authenticated clients to look up a user_profile by email (from auth.users)
-- or phone (from user_profiles).  Uses SECURITY DEFINER so it can JOIN auth.users
-- without granting the caller direct access to that table.

create or replace function public.find_user_by_contact(
  p_email text default null,
  p_phone text default null
)
returns table(
  user_id    uuid,
  full_name  text,
  job_title  text,
  phone      text,
  avatar_url text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    up.user_id,
    up.full_name,
    up.job_title,
    up.phone,
    up.avatar_url
  from public.user_profiles up
  join auth.users au on au.id = up.user_id
  where
    (p_email is not null and p_email <> ''
     and lower(au.email) = lower(p_email))
    or
    (p_phone is not null and p_phone <> ''
     and up.phone = p_phone)
  limit 1;
end;
$$;

revoke execute on function public.find_user_by_contact(text, text) from anon;
grant  execute on function public.find_user_by_contact(text, text) to authenticated;
