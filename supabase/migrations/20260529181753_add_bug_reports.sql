create table if not exists bug_reports (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete cascade not null,
  title        text not null,
  description  text,
  app_version  text,
  platform     text,
  created_at   timestamptz not null default now()
);

alter table bug_reports enable row level security;

-- Users can only insert their own reports; no read/update/delete from client
create policy "Users insert own bug_reports"
  on bug_reports for insert
  with check (user_id = auth.uid());

grant insert on "public"."bug_reports" to "authenticated";
