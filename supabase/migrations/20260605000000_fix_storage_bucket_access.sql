-- Security fix: make all storage buckets private so files require authentication.
-- Previously, repair_receipts, transaction_receipts, avatars, and application-documents
-- were public=true, meaning any stored URL was readable by the entire internet without auth.

update storage.buckets
set public = false
where id in (
  'repair_receipts',
  'transaction_receipts',
  'avatars',
  'application-documents'
);

-- Drop blanket public read policies --

drop policy if exists "Repair receipts are publicly readable" on storage.objects;
drop policy if exists "Avatars are publicly readable" on storage.objects;

-- Add authenticated-only read policies --

-- repair_receipts: only the owning user can read their receipts
create policy "Users can read their own repair receipts"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'repair_receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- avatars: only the owning user can read their avatars
create policy "Users can read their own avatars"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- transaction_receipts already has "for all" policy covering select; no new policy needed.
-- application-documents already has "for all" policy with auth.uid() check; no new policy needed.
