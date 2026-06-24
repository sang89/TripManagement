-- Bug: claim_tenant_invite created a tenant record without profile_id, so it
-- didn't appear in the landlord's profile-scoped "Manage Tenants" list. Set the
-- new tenant's profile_id from its property, and backfill existing rows.

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

  if v_link.tenant_user_id is not null and v_link.tenant_user_id <> v_uid then
    return jsonb_build_object('error', 'not_your_invite');
  end if;

  v_tenant_id := v_link.tenant_id;

  if v_tenant_id is null then
    select email into v_email from auth.users where id = v_uid;

    select t.id into v_tenant_id
    from tenants t
    where t.property_id = v_link.property_id
      and v_email is not null and lower(t.email) = lower(v_email)
      and not exists (
        select 1 from tenant_links tl
        where tl.tenant_id = t.id and tl.status = 'active'
      )
    limit 1;

    if v_tenant_id is null then
      select nullif(full_name, '') into v_name
      from user_profiles where user_id = v_uid;
      -- profile_id inherited from the property so the landlord's profile-scoped
      -- tenant list includes this record.
      insert into tenants (property_id, profile_id, name, email, status)
      values (v_link.property_id,
              (select profile_id from properties where id = v_link.property_id),
              coalesce(v_name, split_part(coalesce(v_email, ''), '@', 1), 'Tenant'),
              coalesce(v_email, ''), 'active')
      returning id into v_tenant_id;
    end if;
  end if;

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

-- Backfill: tenants missing a profile inherit their property's profile.
update tenants t
set profile_id = p.profile_id
from properties p
where t.property_id = p.id
  and t.profile_id is null
  and p.profile_id is not null;
