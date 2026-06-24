-- Tenant portal foundation: link landlord-owned tenant records to real auth
-- users, let linked tenants file requests + self-report payments, and keep all
-- existing landlord-only access intact.
--
-- Design notes:
--   * Existing landlord policies are `FOR ALL ... USING (...)` with no WITH CHECK.
--     Postgres OR-combines permissive policies, so every tenant policy added here
--     is purely ADDITIVE and cannot narrow landlord access.
--   * Tenant read/write policies call SECURITY DEFINER helpers (defined below)
--     instead of inlining `in (select ... from tenant_links join ...)`. The
--     helpers read tenant_links with RLS bypassed, which breaks the otherwise
--     recursive policy-evaluation chain (tenants -> tenant_links -> ...).
--   * Shared Supabase project (TripManagement): every new table carries an
--     `app_id` column defaulting to 'property_management'.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. tenant_links: ownership bridge + approval lifecycle
-- ─────────────────────────────────────────────────────────────────────────────
create table tenant_links (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants(id) on delete cascade,
  -- property_id + landlord_user_id are denormalized so the RLS helpers can read
  -- a single table without re-entering tenants/properties (recursion guard).
  property_id      uuid not null references properties(id) on delete cascade,
  landlord_user_id uuid not null references auth.users(id) on delete cascade,
  -- NULL until a Phase B email invitee creates an account, then back-filled.
  tenant_user_id   uuid references auth.users(id) on delete set null,
  invited_email    text not null,
  status           text not null default 'invited'
                   check (status in ('invited','active','declined','revoked','expired')),
  invite_token     uuid not null default gen_random_uuid(),
  invited_at       timestamptz not null default now(),
  responded_at     timestamptz,
  app_id           text not null default 'property_management',
  created_at       timestamptz not null default now()
);

-- One link per (tenant, user); prevents duplicate active invites.
create unique index tenant_links_tenant_user_uidx
  on tenant_links (tenant_id, tenant_user_id)
  where tenant_user_id is not null;

-- Hot RLS path: "is this user an active tenant of property X".
create index tenant_links_active_user_property_idx
  on tenant_links (tenant_user_id, property_id)
  where status = 'active' and tenant_user_id is not null;

create index tenant_links_tenant_id_idx   on tenant_links (tenant_id);
create index tenant_links_property_id_idx on tenant_links (property_id);
create index tenant_links_email_idx       on tenant_links (invited_email) where status = 'invited';

alter table tenant_links enable row level security;

-- SELECT-only for end users; both parties see their own links. There is NO
-- insert/update/delete policy on purpose — all writes go through the
-- `tenant-invite` edge function (service role), so a user can never
-- self-promote a link from 'invited' to 'active'.
create policy "tenant sees own links"
  on tenant_links for select
  using (tenant_user_id = auth.uid());

create policy "landlord sees own links"
  on tenant_links for select
  using (landlord_user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Anti-recursion RLS helpers (SECURITY DEFINER => RLS bypassed inside body)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function is_active_tenant_user(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from tenant_links tl
    where tl.tenant_id = p_tenant_id
      and tl.tenant_user_id = auth.uid()
      and tl.status = 'active'
  );
$$;

create or replace function tenant_can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from tenant_links tl
    where tl.property_id = p_property_id
      and tl.tenant_user_id = auth.uid()
      and tl.status = 'active'
  );
$$;

revoke all on function is_active_tenant_user(uuid)      from public;
revoke all on function tenant_can_access_property(uuid) from public;
grant execute on function is_active_tenant_user(uuid)      to authenticated;
grant execute on function tenant_can_access_property(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. tenant_requests: structured repair / general tickets from tenants
-- ─────────────────────────────────────────────────────────────────────────────
create table tenant_requests (
  id            uuid primary key default gen_random_uuid(),
  property_id   uuid not null references properties(id) on delete cascade,
  tenant_id     uuid references tenants(id) on delete set null,
  created_by    uuid not null references auth.users(id),
  kind          text not null default 'repair'
                check (kind in ('repair','general')),
  title         text not null default '',
  description   text not null default '',
  status        text not null default 'requested'
                check (status in ('requested','acknowledged','in_progress','resolved','declined')),
  photo_urls    text[] not null default '{}',
  repair_id     uuid references repairs(id) on delete set null,
  landlord_note text not null default '',
  app_id        text not null default 'property_management',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index tenant_requests_property_id_idx on tenant_requests (property_id);
create index tenant_requests_created_by_idx  on tenant_requests (created_by);
create index tenant_requests_tenant_id_idx   on tenant_requests (tenant_id);

alter table tenant_requests enable row level security;

-- Landlord: full control over requests on properties they own.
create policy "landlord manages property requests"
  on tenant_requests for all
  using (property_id in (select id from properties where user_id = auth.uid()));

-- Tenant: may file a new request for a property they're linked to.
create policy "tenant inserts request for their property"
  on tenant_requests for insert
  with check (
    tenant_can_access_property(property_id)
    and created_by = auth.uid()
    and status = 'requested'
  );

-- Tenant: reads their own requests.
create policy "tenant reads own requests"
  on tenant_requests for select
  using (created_by = auth.uid());

-- Tenant: may edit only their own still-open request (add photos / cancel).
create policy "tenant updates own open request"
  on tenant_requests for update
  using (created_by = auth.uid() and status in ('requested','acknowledged'))
  with check (created_by = auth.uid() and status in ('requested','acknowledged'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. repairs: provenance link back to the originating request + tenant read
-- ─────────────────────────────────────────────────────────────────────────────
alter table repairs
  add column if not exists requested_by_tenant_id uuid references tenants(id) on delete set null,
  add column if not exists source_request_id      uuid references tenant_requests(id) on delete set null;

-- Tenants intentionally get NO direct access to `repairs` (the row carries cost /
-- contractor, which are landlord-internal). They watch progress via the status
-- on their own `tenant_requests` row, which the landlord advances.

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. rent_payments: two-step self-report (tenant_reported -> paid|rejected)
-- ─────────────────────────────────────────────────────────────────────────────
alter table rent_payments drop constraint if exists rent_payments_status_check;
alter table rent_payments add constraint rent_payments_status_check
  check (status in ('pending','tenant_reported','paid','overdue','waived','rejected'));

alter table rent_payments
  add column if not exists reported_amount  numeric,
  add column if not exists reported_method  text,
  add column if not exists reported_date    date,
  add column if not exists reported_by      uuid references auth.users(id),
  add column if not exists reported_at      timestamptz,
  add column if not exists confirmed_by     uuid references auth.users(id),
  add column if not exists confirmed_at     timestamptz,
  add column if not exists rejection_reason text;

-- Tenant: read their own payment ledger.
create policy "linked tenant reads own rent payments"
  on rent_payments for select
  using (is_active_tenant_user(tenant_id));

-- Tenant: self-report a payment (only into the 'tenant_reported' state).
create policy "linked tenant inserts self-report payment"
  on rent_payments for insert
  with check (
    is_active_tenant_user(tenant_id)
    and status = 'tenant_reported'
    and reported_by = auth.uid()
  );

-- Tenant: report against a not-yet-settled payment, or edit an existing report.
-- USING governs which rows may be targeted (pre-update state): any of the
-- tenant's payments that aren't already paid/waived. WITH CHECK governs the
-- result (post-update state): it must end in 'tenant_reported' owned by the
-- caller, so a tenant can never set 'paid' nor un-settle a paid/waived row.
create policy "linked tenant updates own self-report"
  on rent_payments for update
  using (
    is_active_tenant_user(tenant_id)
    and status in ('pending','overdue','tenant_reported','rejected')
  )
  with check (
    is_active_tenant_user(tenant_id)
    and status = 'tenant_reported'
    and reported_by = auth.uid()
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. tenants / properties / leases: minimal tenant read access
-- ─────────────────────────────────────────────────────────────────────────────
create policy "linked tenant reads own tenant row"
  on tenants for select
  using (is_active_tenant_user(id));

create policy "linked tenant reads own leases"
  on leases for select
  using (is_active_tenant_user(tenant_id));

-- Tenants do NOT get a row policy on `properties` (that would expose every
-- column, incl. purchase price / valuation). Instead they read a basic-columns
-- view: SECURITY DEFINER bypasses base-table RLS, and the WHERE clause scopes
-- rows to the caller's active links. Financial columns are zeroed out so the
-- shape still satisfies Property.fromJson without leaking values.
create view tenant_property_view
with (security_invoker = off) as
  select
    p.id,
    p.user_id,
    p.profile_id,
    p.name,
    p.address,
    p.city,
    p.state,
    p.zip_code,
    p.property_type,
    p.ownership_type,
    p.square_footage,
    p.bedrooms,
    p.bathrooms,
    p.year_built,
    p.purchase_date,
    p.created_at,
    0::numeric        as purchase_price,
    0::numeric        as current_value,
    null::numeric     as estimated_value,
    null::timestamptz as value_estimated_at,
    ''::text          as notes
  from properties p
  where tenant_can_access_property(p.id);

grant select on tenant_property_view to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. notifications: new types for the invite / payment / request handshakes
-- ─────────────────────────────────────────────────────────────────────────────
alter table notifications drop constraint notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type in (
    'lease_expiry','system','monthly_summary','rent_overdue',
    'tenant_invite','tenant_request','payment_reported','payment_confirmed','request_update'
  ));
