-- Look up an auth user id by email for the tenant-invite edge function (Phase A:
-- link only users who already have an account). SECURITY DEFINER so it can read
-- auth.users; executable ONLY by service_role so clients can't enumerate emails.
create or replace function find_auth_user_id_by_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function find_auth_user_id_by_email(text) from public, anon, authenticated;
grant execute on function find_auth_user_id_by_email(text) to service_role;
