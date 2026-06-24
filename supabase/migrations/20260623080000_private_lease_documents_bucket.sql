-- Make lease-documents bucket private.
-- The storage RLS policy already restricts reads to the file owner
-- (storage.foldername(name))[1] = auth.uid()), so making it private means
-- the public URL no longer works — callers must use createSignedUrl instead.
update storage.buckets
set public = false
where id = 'lease-documents';
