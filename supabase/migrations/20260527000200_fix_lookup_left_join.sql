-- Fix find_user_by_contact: use LEFT JOIN so users who exist in auth.users
-- but have not yet created a user_profiles row are still returned.
-- Profile fields (full_name, job_title, phone, avatar_url) will be NULL/empty
-- for those users.

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
    au.id                           as user_id,
    coalesce(up.full_name,   '')    as full_name,
    coalesce(up.job_title,   '')    as job_title,
    coalesce(up.phone,       '')    as phone,
    coalesce(up.avatar_url,  '')    as avatar_url
  from auth.users au
  left join public.user_profiles up on up.user_id = au.id
  where
    (p_email is not null and p_email <> ''
     and lower(au.email) = lower(p_email))
    or
    (p_phone is not null and p_phone <> ''
     and right(regexp_replace(coalesce(up.phone, ''), '[^0-9]', '', 'g'), 10)
       = right(regexp_replace(p_phone,              '[^0-9]', '', 'g'), 10))
  limit 1;
end;
$$;

revoke execute on function public.find_user_by_contact(text, text) from anon;
grant  execute on function public.find_user_by_contact(text, text) to authenticated;
