-- Lets an invitee permanently opt out of being re-invited to a specific trip.
-- When block_reinvite = true on their trip_members row:
--   • The DB trigger rejects any UPDATE that would set status = 'pending'.
--   • The Flutter provider fast-rejects before even hitting the DB.
--   • The organiser sees a clear error message instead of a silent failure.

-- ── 1. Column ─────────────────────────────────────────────────────────────────
alter table trip_members
  add column if not exists block_reinvite boolean not null default false;

-- ── 2. Guard trigger ──────────────────────────────────────────────────────────
create or replace function public.prevent_blocked_reinvite()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and old.block_reinvite = true
     and new.status = 'pending' then
    raise exception 'blocked_reinvite'
      using detail = 'User has opted out of future invitations to this trip';
  end if;
  return new;
end;
$$;

create trigger on_member_reinvite_check
  before update on public.trip_members
  for each row execute function public.prevent_blocked_reinvite();
