-- DB trigger that calls the send-invite-notification Edge Function via pg_net
-- whenever a trip_members row is inserted with status='pending'.
--
-- Prerequisites (run once before the first invite is sent — never commit these):
--
--   1. Store the service role key in Supabase Vault:
--        select vault.create_secret('<service_role_key>', 'service_role_key');
--      (Run via: supabase db execute --linked --file path/to/seed_vault.sql)
--
--   2. Set the Edge Function secrets:
--        supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<json>'
--        supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<key>'

-- pg_net is enabled by default on Supabase projects.
create extension if not exists pg_net schema extensions;

create or replace function public.handle_new_invite()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_service_role_key text;
begin
  if new.status = 'pending' and new.user_id is not null then
    -- Read service role key from Vault (populated via vault.create_secret).
    -- If not yet configured the trigger silently skips (no error).
    select decrypted_secret into v_service_role_key
    from vault.decrypted_secrets
    where name = 'service_role_key'
    limit 1;

    if v_service_role_key is not null then
      perform net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                   || '/functions/v1/send-invite-notification',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body    := jsonb_build_object(
          'member_id',       new.id,
          'trip_id',         new.trip_id,
          'invitee_user_id', new.user_id
        )
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger on_invite_inserted
  after insert on public.trip_members
  for each row execute function public.handle_new_invite();
