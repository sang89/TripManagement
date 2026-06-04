-- Realtime publication and storage bucket for the Events feature.

-- ── Realtime ──────────────────────────────────────────────────────────────────

ALTER TABLE events          REPLICA IDENTITY DEFAULT;
ALTER TABLE event_guests    REPLICA IDENTITY FULL;   -- DELETE needs event_id
ALTER TABLE event_messages  REPLICA IDENTITY DEFAULT;
ALTER TABLE event_photos    REPLICA IDENTITY FULL;   -- DELETE needs event_id
ALTER TABLE event_expenses  REPLICA IDENTITY DEFAULT;

ALTER PUBLICATION supabase_realtime ADD TABLE events;
ALTER PUBLICATION supabase_realtime ADD TABLE event_guests;
ALTER PUBLICATION supabase_realtime ADD TABLE event_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE event_photos;
ALTER PUBLICATION supabase_realtime ADD TABLE event_expenses;

-- ── Storage bucket ────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('event-photos', 'event-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users who are event members can upload photos.
CREATE POLICY "event_photos_storage_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'event-photos' AND auth.uid() IS NOT NULL);

-- Anyone can view photos (bucket is public).
CREATE POLICY "event_photos_storage_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'event-photos');

-- Uploader can delete their own photos; path prefix is event_id/photo_id.
CREATE POLICY "event_photos_storage_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'event-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
