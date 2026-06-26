-- Add house rules and AI auto-triage setting to properties.
-- house_rules: landlord-written rules the AI review gate evaluates requests against.
-- auto_triage_requests: when true, a Supabase edge function automatically assigns
--   a contractor and creates the linked repair when a request is accepted.
alter table properties
  add column if not exists house_rules          text    not null default '',
  add column if not exists auto_triage_requests boolean not null default false;
