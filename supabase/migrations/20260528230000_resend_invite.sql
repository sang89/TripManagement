-- Adds resend_invite(p_member_id uuid) RPC so the client can re-send the FCM
-- push for an already-pending invite without changing the member's status.
--
-- The existing on_invite_inserted trigger only fires when status transitions
-- *to* 'pending', so a pending-to-pending UPDATE would not re-notify.
-- This function bypasses that by calling the Edge Function directly via pg_net
-- using the same Vault key and payload shape.

create or replace function public.resend_invite(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_member       trip_members%rowtype;
  v_authorized   boolean;
  v_svc_key      text;
begin
  select * into v_member from trip_members where id = p_member_id;
  if not found then
    raise exception 'member_not_found';
  end if;

  if v_member.status <> 'pending' or v_member.user_id is null then
    raise exception 'not_pending_linked_invite';
  end if;

  select (
    exists (select 1 from trips where id = v_member.trip_id and created_by = auth.uid())
    or auth_user_is_trip_member(v_member.trip_id)
  ) into v_authorized;

  if not v_authorized then
    raise exception 'unauthorized';
  end if;

  select decrypted_secret into v_svc_key
  from vault.decrypted_secrets
  where name = 'service_role_key'
  limit 1;

  if v_svc_key is not null then
    perform net.http_post(
      url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                 || '/functions/v1/send-invite-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_svc_key
      ),
      body    := jsonb_build_object(
        'member_id',       p_member_id,
        'trip_id',         v_member.trip_id,
        'invitee_user_id', v_member.user_id
      )
    );
  end if;
end;
$$;

grant execute on function public.resend_invite(uuid) to authenticated;
