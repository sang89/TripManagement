-- Allow re-inviting a member who left (or declined) without creating a duplicate row.
--
-- 1. Partial unique index — one membership row per (trip, linked user).
--    Guest members (user_id IS NULL) are exempt: a trip can have multiple unnamed guests.
--
-- 2. handle_new_invite() extended to also fire on UPDATE when status transitions
--    *to* 'pending' (re-invite after leaving or declining).
--
-- 3. Trigger re-created as AFTER INSERT OR UPDATE.

-- ── 1. Partial unique index ───────────────────────────────────────────────────
create unique index if not exists trip_members_trip_user_unique
  on trip_members(trip_id, user_id)
  where user_id is not null;

-- ── 2. Extended trigger function ──────────────────────────────────────────────
create or replace function public.handle_new_invite()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_service_role_key text;
begin
  -- Fire when:
  --   INSERT: any new pending invite for a linked user
  --   UPDATE: status changes *to* 'pending' (re-invite after leaving / declining)
  if new.status = 'pending' and new.user_id is not null and
     (tg_op = 'INSERT' or (tg_op = 'UPDATE' and old.status is distinct from 'pending')) then

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

-- ── 3. Re-create trigger as INSERT OR UPDATE ──────────────────────────────────
drop trigger if exists on_invite_inserted on public.trip_members;
create trigger on_invite_inserted
  after insert or update on public.trip_members
  for each row execute function public.handle_new_invite();
