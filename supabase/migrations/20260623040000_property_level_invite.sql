-- Smart property-level invites: a code is tied to a PROPERTY (not a specific
-- tenant record). On claim, the joiner is matched by email to a tenant record
-- the landlord already set up (preserving their lease + rent ledger), or a new
-- tenant record is created from their account. Removes the "pick a tenant" step.

-- tenant_id becomes nullable: an open property-level code has property_id set
-- and tenant_id null until claimed and resolved.
alter table tenant_links alter column tenant_id drop not null;

-- ── create_property_invite (landlord): open code for a whole property ─────────
create or replace function create_property_invite(p_property_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_token uuid;
begin
  if v_uid is null then raise exception 'auth_required'; end if;
  if not exists (
    select 1 from properties where id = p_property_id and user_id = v_uid
  ) then
    raise exception 'not_your_property';
  end if;

  -- Reuse an existing open (unclaimed, tenant-less) code for this property.
  select invite_token into v_token
  from tenant_links
  where property_id = p_property_id
    and tenant_id is null and tenant_user_id is null and status = 'invited'
  limit 1;
  if v_token is not null then return v_token; end if;

  insert into tenant_links (
    tenant_id, property_id, landlord_user_id, tenant_user_id,
    invited_email, status, app_id
  )
  values (null, p_property_id, v_uid, null, '', 'invited', 'property_management')
  returning invite_token into v_token;
  return v_token;
end;
$$;

revoke all on function create_property_invite(uuid) from public, anon;
grant execute on function create_property_invite(uuid) to authenticated;

-- ── claim_tenant_invite (upgraded): resolve-or-create the tenant on claim ─────
create or replace function claim_tenant_invite(p_invite_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_link      tenant_links%rowtype;
  v_tenant_id uuid;
  v_email     text;
  v_name      text;
begin
  if v_uid is null then raise exception 'auth_required'; end if;

  select * into v_link from tenant_links
  where invite_token = p_invite_token and status = 'invited'
  for update;
  if not found then return jsonb_build_object('error', 'invalid_or_used'); end if;

  -- Account-targeted invites (tenant_user_id set) are claimable only by that user.
  if v_link.tenant_user_id is not null and v_link.tenant_user_id <> v_uid then
    return jsonb_build_object('error', 'not_your_invite');
  end if;

  v_tenant_id := v_link.tenant_id;

  -- Property-level invite: resolve which tenant record the joiner steps into.
  if v_tenant_id is null then
    select email into v_email from auth.users where id = v_uid;

    -- 1) Match an existing, not-yet-linked tenant record by email.
    select t.id into v_tenant_id
    from tenants t
    where t.property_id = v_link.property_id
      and v_email is not null and lower(t.email) = lower(v_email)
      and not exists (
        select 1 from tenant_links tl
        where tl.tenant_id = t.id and tl.status = 'active'
      )
    limit 1;

    -- 2) Otherwise create a fresh tenant record from the joiner's account.
    if v_tenant_id is null then
      select nullif(full_name, '') into v_name
      from user_profiles where user_id = v_uid;
      insert into tenants (property_id, name, email, status)
      values (v_link.property_id,
              coalesce(v_name, split_part(coalesce(v_email, ''), '@', 1), 'Tenant'),
              coalesce(v_email, ''), 'active')
      returning id into v_tenant_id;
    end if;
  end if;

  -- Idempotent: already an active tenant of the resolved record.
  if exists (
    select 1 from tenant_links
    where tenant_id = v_tenant_id and tenant_user_id = v_uid and status = 'active'
  ) then
    update tenant_links set status = 'revoked' where id = v_link.id;
    return jsonb_build_object('success', true, 'already_linked', true,
                              'property_id', v_link.property_id);
  end if;

  update tenant_links
    set tenant_id = v_tenant_id, tenant_user_id = v_uid,
        status = 'active', responded_at = now()
  where id = v_link.id;

  insert into notifications (user_id, app_id, type, title, body, reference_id)
  values (v_link.landlord_user_id, 'property_management', 'request_update',
          'Tenant joined', 'A tenant joined your rental via invite code.',
          v_link.id)
  on conflict do nothing;

  return jsonb_build_object('success', true, 'property_id', v_link.property_id,
                            'tenant_id', v_tenant_id);
end;
$$;

revoke all on function claim_tenant_invite(uuid) from public, anon;
grant execute on function claim_tenant_invite(uuid) to authenticated;
