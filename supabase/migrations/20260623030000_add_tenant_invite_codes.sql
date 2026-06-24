-- QR / invite-code flow for the tenant portal, mirroring TripManagement's
-- proven rsvp_session pattern: the invite is the tenant_links.invite_token UUID
-- (encoded client-side via InviteCodec for QR/sharing). A landlord generates an
-- open code for a tenant; anyone signed in can claim it. All writes are through
-- SECURITY DEFINER functions using auth.uid(), so clients can't forge links.

-- ── create_tenant_invite (landlord): get-or-create an open code for a tenant ──
create or replace function create_tenant_invite(p_tenant_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_prop  uuid;
  v_token uuid;
begin
  if v_uid is null then raise exception 'auth_required'; end if;

  select property_id into v_prop from tenants where id = p_tenant_id;
  if v_prop is null then raise exception 'tenant_not_found'; end if;
  if not exists (
    select 1 from properties where id = v_prop and user_id = v_uid
  ) then
    raise exception 'not_your_tenant';
  end if;

  -- Reuse an existing open (unclaimed) code for this tenant if present.
  select invite_token into v_token
  from tenant_links
  where tenant_id = p_tenant_id and tenant_user_id is null and status = 'invited'
  limit 1;
  if v_token is not null then return v_token; end if;

  insert into tenant_links (
    tenant_id, property_id, landlord_user_id, tenant_user_id,
    invited_email, status, app_id
  )
  values (p_tenant_id, v_prop, v_uid, null, '', 'invited', 'property_management')
  returning invite_token into v_token;
  return v_token;
end;
$$;

revoke all on function create_tenant_invite(uuid) from public, anon;
grant execute on function create_tenant_invite(uuid) to authenticated;

-- ── get_tenant_invite (preview before claiming) ──────────────────────────────
create or replace function get_tenant_invite(p_invite_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link      tenant_links%rowtype;
  v_prop_name text;
  v_prop_addr text;
  v_landlord  text;
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;

  select * into v_link from tenant_links
  where invite_token = p_invite_token and status = 'invited'
  limit 1;
  if not found then return jsonb_build_object('error', 'invalid_or_used'); end if;

  select name, address into v_prop_name, v_prop_addr
  from properties where id = v_link.property_id;
  select coalesce(nullif(display_name, ''), 'Landlord') into v_landlord
  from profiles where user_id = v_link.landlord_user_id and is_default = true
  limit 1;

  return jsonb_build_object(
    'property_name', coalesce(v_prop_name, ''),
    'property_address', coalesce(v_prop_addr, ''),
    'landlord_name', coalesce(v_landlord, '')
  );
end;
$$;

revoke all on function get_tenant_invite(uuid) from public, anon;
grant execute on function get_tenant_invite(uuid) to authenticated;

-- ── claim_tenant_invite (tenant): join a rental via the code ─────────────────
create or replace function claim_tenant_invite(p_invite_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_link tenant_links%rowtype;
begin
  if v_uid is null then raise exception 'auth_required'; end if;

  select * into v_link from tenant_links
  where invite_token = p_invite_token and status = 'invited'
  for update;
  if not found then return jsonb_build_object('error', 'invalid_or_used'); end if;

  -- An account-targeted invite (tenant_user_id set) can only be claimed by that
  -- user; open code invites (tenant_user_id null) are claimable by anyone.
  if v_link.tenant_user_id is not null and v_link.tenant_user_id <> v_uid then
    return jsonb_build_object('error', 'not_your_invite');
  end if;

  -- Idempotent: if already an active tenant of this record, consume the code.
  if exists (
    select 1 from tenant_links
    where tenant_id = v_link.tenant_id and tenant_user_id = v_uid and status = 'active'
  ) then
    if v_link.tenant_user_id is null then
      update tenant_links set status = 'revoked' where id = v_link.id;
    end if;
    return jsonb_build_object('success', true, 'already_linked', true,
                              'property_id', v_link.property_id);
  end if;

  update tenant_links
    set tenant_user_id = v_uid, status = 'active', responded_at = now()
  where id = v_link.id;

  insert into notifications (user_id, app_id, type, title, body, reference_id)
  values (v_link.landlord_user_id, 'property_management', 'request_update',
          'Tenant joined', 'A tenant joined your rental via invite code.',
          v_link.id)
  on conflict do nothing;

  return jsonb_build_object('success', true, 'property_id', v_link.property_id,
                            'tenant_id', v_link.tenant_id);
end;
$$;

revoke all on function claim_tenant_invite(uuid) from public, anon;
grant execute on function claim_tenant_invite(uuid) to authenticated;
