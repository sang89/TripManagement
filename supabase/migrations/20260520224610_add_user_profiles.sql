create table "public"."user_profiles" (
  "id"               uuid        not null default gen_random_uuid(),
  "user_id"          uuid        not null references auth.users(id) on delete cascade,
  "full_name"        text        not null default '',
  "job_title"        text        not null default '',
  "phone"            text        not null default '',
  "company_name"     text        not null default '',
  "business_address" text        not null default '',
  "created_at"       timestamptz not null default now(),
  "updated_at"       timestamptz not null default now(),
  constraint "user_profiles_pkey" primary key ("id"),
  constraint "user_profiles_user_id_key" unique ("user_id")
);

alter table "public"."user_profiles" enable row level security;

create policy "Users can view their own profile"
  on user_profiles for select using (user_id = auth.uid());

create policy "Users can insert their own profile"
  on user_profiles for insert with check (user_id = auth.uid());

create policy "Users can update their own profile"
  on user_profiles for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on table "public"."user_profiles" to "authenticated";
grant select, insert, update, delete on table "public"."user_profiles" to "service_role";

create or replace function public.handle_user_profiles_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.handle_user_profiles_updated_at();
