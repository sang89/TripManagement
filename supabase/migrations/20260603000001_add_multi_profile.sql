-- Add multi-profile support (Pro feature)
-- Each user can have up to 3 named profiles (personal, business, other).
-- All top-level data tables gain a profile_id FK so data is fully isolated.

-- 1. profiles table (absorbs user_profiles concept, adds display_name / type / is_default)
create table profiles (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references auth.users(id) on delete cascade not null,
  display_name     text not null default 'Personal',
  type             text not null default 'personal'
                     check (type in ('personal', 'business', 'other')),
  full_name        text,
  job_title        text,
  phone            text,
  company_name     text,
  business_address text,
  avatar_url       text,
  is_default       boolean not null default false,
  created_at       timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles_own"
  on profiles for all
  using (user_id = auth.uid());

create index profiles_user_id_idx on profiles (user_id);

-- 2. Migrate existing user_profiles rows into profiles (one default profile per user)
insert into profiles
  (user_id, display_name, type, full_name, job_title, phone,
   company_name, business_address, avatar_url, is_default)
select
  user_id, 'Personal', 'personal', full_name, job_title, phone,
  company_name, business_address, avatar_url, true
from user_profiles;

-- 3. Add profile_id FK to all top-level data tables (nullable; backfilled below)
alter table properties             add column profile_id uuid references profiles(id) on delete set null;
alter table contractors            add column profile_id uuid references profiles(id) on delete set null;
alter table financial_transactions add column profile_id uuid references profiles(id) on delete set null;
alter table transaction_groups     add column profile_id uuid references profiles(id) on delete set null;
alter table transaction_labels     add column profile_id uuid references profiles(id) on delete set null;
alter table user_payment_methods   add column profile_id uuid references profiles(id) on delete set null;

-- 4. Backfill profile_id using each user's default profile
update properties t
  set profile_id = p.id
  from profiles p
  where p.user_id = t.user_id and p.is_default = true;

update contractors t
  set profile_id = p.id
  from profiles p
  where p.user_id = t.user_id and p.is_default = true;

update financial_transactions t
  set profile_id = p.id
  from profiles p
  where p.user_id = t.user_id and p.is_default = true;

update transaction_groups t
  set profile_id = p.id
  from profiles p
  where p.user_id = t.user_id and p.is_default = true;

update transaction_labels t
  set profile_id = p.id
  from profiles p
  where p.user_id = t.user_id and p.is_default = true;

update user_payment_methods t
  set profile_id = p.id
  from profiles p
  where p.user_id = t.user_id and p.is_default = true;
