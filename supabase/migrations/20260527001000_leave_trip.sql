-- Allow accepted members to leave a trip (delete their own row).
-- Also set REPLICA IDENTITY FULL on trip_members so that real-time DELETE
-- events carry the full old row (trip_id, user_id, etc.) — not just the PK.
-- Without FULL, payload.oldRecord only contains {id} and other clients cannot
-- locate which trip to update.

-- ── 1. Replica identity ────────────────────────────────────────────────────
alter table public.trip_members replica identity full;

-- ── 2. Allow self-deletion (leaving) ──────────────────────────────────────
-- The original policy only let the organizer delete member rows.
-- We add a second policy for members deleting their own row.
-- The organizer policy is intentionally kept separate so it is obvious
-- that organizers can still remove any member.
create policy "trip_members_leave" on trip_members
  for delete
  using (user_id = auth.uid());
