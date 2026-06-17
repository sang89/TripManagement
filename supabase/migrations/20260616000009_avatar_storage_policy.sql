-- ─────────────────────────────────────────────────────────────────────────────
-- Extend avatars storage policies to allow TripManagement-specific paths.
--
-- TripManagement stores avatars at trip/{userId}/avatar so they don't
-- overwrite PropertyManagement avatars at {userId}/avatar.
-- All four CRUD policies need to accept either path pattern.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER POLICY "Users can upload their own avatar" ON storage.objects
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = (auth.uid())::text
      OR ((storage.foldername(name))[1] = 'trip'
          AND (storage.foldername(name))[2] = (auth.uid())::text)
    )
  );

ALTER POLICY "Users can read their own avatars" ON storage.objects
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = (auth.uid())::text
      OR ((storage.foldername(name))[1] = 'trip'
          AND (storage.foldername(name))[2] = (auth.uid())::text)
    )
  );

ALTER POLICY "Users can update their own avatar" ON storage.objects
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = (auth.uid())::text
      OR ((storage.foldername(name))[1] = 'trip'
          AND (storage.foldername(name))[2] = (auth.uid())::text)
    )
  );

ALTER POLICY "Users can delete their own avatar" ON storage.objects
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = (auth.uid())::text
      OR ((storage.foldername(name))[1] = 'trip'
          AND (storage.foldername(name))[2] = (auth.uid())::text)
    )
  );
