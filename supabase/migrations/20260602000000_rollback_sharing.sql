-- Rollback all account-sharing migrations (000003 through 000008).
-- Restores every RLS policy to its original owner-only form and removes
-- all sharing-specific tables, columns, and helper functions.

-- ─── Undo 000008: drop owner_name column ────────────────────────────────────
alter table account_shares drop column if exists owner_name;

-- ─── Undo 000007: restore user_profiles SELECT policy ───────────────────────
drop policy if exists "users_view_own_and_shared_profiles" on user_profiles;

-- ─── Undo 000006: drop owner_email column ───────────────────────────────────
alter table account_shares drop column if exists owner_email;

-- ─── Undo 000005: drop professional add-on columns ──────────────────────────
alter table user_subscriptions
  drop column if exists professional_addon,
  drop column if exists managed_account_seats;

-- ─── Undo 000004 + 000007: restore all data-table RLS to owner-only ─────────

-- user_profiles
drop policy if exists "Users can view their own profile" on user_profiles;
create policy "Users can view their own profile"
  on user_profiles for select
  using (user_id = auth.uid());

-- properties
drop policy if exists "Users manage own properties" on properties;
create policy "Users manage own properties"
  on properties for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- mortgages
drop policy if exists "Users manage own mortgages" on mortgages;
create policy "Users manage own mortgages"
  on mortgages for all
  using (
    exists (
      select 1 from properties
      where properties.id = mortgages.property_id
        and properties.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from properties
      where properties.id = mortgages.property_id
        and properties.user_id = auth.uid()
    )
  );

-- insurances
drop policy if exists "Users can manage their own insurances" on insurances;
create policy "Users can manage their own insurances"
  on insurances for all
  using (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  )
  with check (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  );

-- repairs
drop policy if exists "Users manage own repairs" on repairs;
create policy "Users manage own repairs"
  on repairs for all
  using (
    exists (
      select 1 from properties
      where properties.id = repairs.property_id
        and properties.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from properties
      where properties.id = repairs.property_id
        and properties.user_id = auth.uid()
    )
  );

-- house_info_items
drop policy if exists "Users manage own house info" on house_info_items;
create policy "Users manage own house info"
  on house_info_items for all
  using (
    exists (
      select 1 from properties
      where properties.id = house_info_items.property_id
        and properties.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from properties
      where properties.id = house_info_items.property_id
        and properties.user_id = auth.uid()
    )
  );

-- tenants
drop policy if exists "Users can manage their own tenants" on tenants;
create policy "Users can manage their own tenants"
  on tenants for all
  using (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  )
  with check (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  );

-- tenant_members
drop policy if exists "Users can manage their own tenant members" on tenant_members;
create policy "Users can manage their own tenant members"
  on tenant_members for all
  using (
    tenant_id in (
      select id from tenants where property_id in (
        select id from properties where user_id = auth.uid()
      )
    )
  )
  with check (
    tenant_id in (
      select id from tenants where property_id in (
        select id from properties where user_id = auth.uid()
      )
    )
  );

-- rent_payments
drop policy if exists "Users can manage their own rent payments" on rent_payments;
create policy "Users can manage their own rent payments"
  on rent_payments for all
  using (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  )
  with check (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  );

-- rental_applications
drop policy if exists "Users manage own rental applications" on rental_applications;
create policy "Users manage own rental applications"
  on rental_applications for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- application_members
drop policy if exists "Users manage own application members" on application_members;
create policy "Users manage own application members"
  on application_members for all
  using (
    application_id in (
      select id from rental_applications where user_id = auth.uid()
    )
  )
  with check (
    application_id in (
      select id from rental_applications where user_id = auth.uid()
    )
  );

-- application_documents
drop policy if exists "Users manage own application documents" on application_documents;
create policy "Users manage own application documents"
  on application_documents for all
  using (
    application_id in (
      select id from rental_applications where user_id = auth.uid()
    )
  )
  with check (
    application_id in (
      select id from rental_applications where user_id = auth.uid()
    )
  );

-- financial_transactions
drop policy if exists "Users manage own financial_transactions" on financial_transactions;
create policy "Users manage own financial_transactions"
  on financial_transactions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- transaction_groups
drop policy if exists "Users manage own transaction_groups" on transaction_groups;
create policy "Users manage own transaction_groups"
  on transaction_groups for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- transaction_labels
drop policy if exists "Users manage own labels" on transaction_labels;
create policy "Users manage own labels"
  on transaction_labels for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- user_payment_methods
drop policy if exists "Users can manage their own payment methods" on user_payment_methods;
create policy "Users can manage their own payment methods"
  on user_payment_methods for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- contractors
drop policy if exists "Users manage own contractors" on contractors;
create policy "Users manage own contractors"
  on contractors for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ─── Undo 000003: drop account_shares table then helper functions ─────────────
-- Table must be dropped first; its RLS policies reference auth_email().
drop table if exists account_shares;
drop function if exists public.has_share_write(uuid, text);
drop function if exists public.has_share_read(uuid, text);
drop function if exists public.auth_email();
