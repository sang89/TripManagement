-- ── 1. event_photos UPDATE policy ─────────────────────────────────────────────
-- Was missing entirely — updatePhotoCaption was silently blocked by RLS.
-- Only the uploader may edit their own photo's caption.

CREATE POLICY "event_photos_update" ON event_photos
  FOR UPDATE
  USING  (uploaded_by = auth.uid())
  WITH CHECK (uploaded_by = auth.uid());

-- ── 2. Fix storage upload policy ──────────────────────────────────────────────
-- Original only checked auth.uid() IS NOT NULL — any authenticated user could
-- upload to any event's folder, burning other events' storage quota.
-- Now requires the caller to be an accepted member of the target event.

DROP POLICY IF EXISTS "event_photos_storage_upload" ON storage.objects;
CREATE POLICY "event_photos_storage_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'event-photos'
    AND public.auth_user_is_event_member(
          (storage.foldername(name))[1]::uuid
        )
  );

-- ── 3. Fix storage delete policy ──────────────────────────────────────────────
-- Original checked auth.uid()::text = (storage.foldername(name))[1], which
-- compares the user UUID to the event UUID — always false. This blocked every
-- client-side storage delete, so orphaned files accumulated indefinitely.
-- The fix joins event_photos to apply the same auth rules as the DB delete
-- policy: uploader OR event organizer.

DROP POLICY IF EXISTS "event_photos_storage_delete" ON storage.objects;
CREATE POLICY "event_photos_storage_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'event-photos'
    AND EXISTS (
      SELECT 1
      FROM   public.event_photos ep
      JOIN   public.events       e  ON e.id = ep.event_id
      WHERE  ep.storage_path        = storage.objects.name
        AND  (ep.uploaded_by = auth.uid() OR e.created_by = auth.uid())
    )
  );
