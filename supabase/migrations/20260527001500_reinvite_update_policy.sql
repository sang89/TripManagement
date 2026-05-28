-- Allow an organizer or accepted member to re-invite a user whose
-- trip_members row currently has status = 'left' or 'declined'.
--
-- Why needed:
--   The upsert in addMember() resolves to an UPDATE when the unique constraint
--   (trip_id, user_id) matches.  The only existing UPDATE policy,
--   trip_members_update_own_status, requires user_id = auth.uid() — which fails
--   when the inviter is updating someone else's row.
--
-- Security constraints:
--   USING  (old row): target row must be in 'left' or 'declined' state, AND the
--                     caller must be the trip organizer or an accepted member.
--   WITH CHECK (new row): the new status must be 'pending' — this policy cannot
--                         be used for any other kind of update.
--
--   The block_reinvite guard trigger (20260527001300) still fires BEFORE this
--   WITH CHECK and will abort the transaction if block_reinvite = true.

create policy "trip_members_reinvite" on trip_members
  for update
  using (
    status in ('left', 'declined')
    and (
      trip_id in (select id from trips where created_by = auth.uid())
      or auth_user_is_trip_member(trip_id)
    )
  )
  with check (
    status = 'pending'
  );
