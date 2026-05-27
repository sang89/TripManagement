-- Fix find_user_by_contact: normalize phone numbers before comparing.
--
-- user_profiles.phone is stored as a raw national number (e.g. "7144669999")
-- while AppPhoneField sends the E.164 value (e.g. "+17144669999").
-- Stripping all non-digits and comparing the trailing 10 digits handles both
-- formats without a schema change.

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
     and right(regexp_replace(up.phone,   '[^0-9]', '', 'g'), 10)
       = right(regexp_replace(p_phone,    '[^0-9]', '', 'g'), 10))
  limit 1;
end;
$$;

revoke execute on function public.find_user_by_contact(text, text) from anon;
grant  execute on function public.find_user_by_contact(text, text) to authenticated;
